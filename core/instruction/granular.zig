const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

const MAX_POLYPHONY: usize = 32;
const HISTORY_BITS = 18;
const HISTORY_SIZE: usize = 1 << HISTORY_BITS;
const HISTORY_MASK: u32 = HISTORY_SIZE - 1;

const Meta = extern struct {
    head: u32,
    grains_to_register: f32,
};

const GrainMeta = extern struct {
    active: bool,
    lifetime: f32,
    cursor: f32,
    speed: f32,
    size: f32,
    fade: f32,
};

inline fn floatCount(comptime T: type) usize {
    return (@sizeOf(T) + @sizeOf(f32) - 1) / @sizeOf(f32);
}

const META_FLOATS = floatCount(Meta);
const GRAIN_META_FLOATS = floatCount(GrainMeta);

fn getHistory(state: []f32) []f32 {
    return state[0..HISTORY_SIZE];
}

fn getMeta(state: []f32) *Meta {
    const bytes = std.mem.sliceAsBytes(state[HISTORY_SIZE .. HISTORY_SIZE + META_FLOATS]);
    return &std.mem.bytesAsSlice(Meta, bytes)[0];
}

fn getGrainMeta(state: []f32) []GrainMeta {
    const bytes = std.mem.sliceAsBytes(state[HISTORY_SIZE + META_FLOATS .. HISTORY_SIZE + META_FLOATS + (MAX_POLYPHONY * GRAIN_META_FLOATS)]);
    return std.mem.bytesAsSlice(GrainMeta, bytes);
}

fn getGrainSlot(grains: []GrainMeta) ?*GrainMeta {
    for (grains) |*g| {
        if (!g.active) {
            return g;
        }
    }
    return null;
}

pub const Granular = struct {
    pub const name = "grains!";
    pub const description = "granular synthesis";

    pub const state_count = HISTORY_SIZE + META_FLOATS + MAX_POLYPHONY * GRAIN_META_FLOATS;

    pub const args: []const meta.Arg = &.{
        .{ .name = "density", .description = "grain density, in grains per second", .default = 0.0 },
        .{ .name = "size", .description = "grain size, in milliseconds", .default = 100.0 },
        .{ .name = "speed", .description = "grain playback speed", .default = 1.0 },
        .{ .name = "position", .description = "grain spawn position, 0 = tail, 1 = head", .default = 0.5 },
        .{ .name = "fade", .description = "grain fade in/out, in milliseconds", .default = 10.0 },
        .{ .name = "in", .description = "input signal" },
    };

    pub fn compile(_: *Node) !@This() {
        return @This(){};
    }

    pub fn eval(
        _: *const @This(),
        sr: f32,
        inputs: []const Block,
        out: *Block,
        state: []f32,
        _: []Block,
    ) void {
        const inv_sr = 1.0 / sr;

        const density = &inputs[0];
        const size = &inputs[1];
        const speed = &inputs[2];
        const position = &inputs[3];
        const fade = &inputs[4];
        const in = &inputs[5];

        const history = getHistory(state);
        const grains = getGrainMeta(state);
        const m = getMeta(state);

        for (
            density.channels[0],
            size.channels[0],
            speed.channels[0],
            position.channels[0],
            fade.channels[0],
        ) |density_vec, size_vec, speed_vec, position_vec, fade_vec| {
            for (0..engine.SIMD_LENGTH) |i| {
                m.grains_to_register += inv_sr * density_vec[i];

                while (m.grains_to_register > 1.0) {
                    m.grains_to_register -= 1.0;

                    const g = getGrainSlot(grains) orelse continue;
                    g.active = true;
                    g.lifetime = 1.0;
                    g.cursor = @mod(@as(f32, @floatFromInt(m.head)) + position_vec[i] * @as(f32, @floatFromInt(HISTORY_SIZE)), @as(f32, @floatFromInt(HISTORY_SIZE)));
                    g.speed = @max(speed_vec[i], 0.2);
                    g.size = @max(size_vec[i], 1.0);
                    g.fade = @max(fade_vec[i], 0.0);
                }
            }
        }

        for (0..engine.BLOCK_LENGTH) |i| {
            history[(m.head + i) & HISTORY_MASK] = 0.0;
        }
        for (in.channels, &out.channels) |in_chan, *out_chan| {
            for (in_chan, out_chan, 0..) |in_vec, *out_vec, i| {
                out_vec.* = @splat(0.0);
                inline for (0..engine.SIMD_LENGTH) |j| {
                    history[(m.head + i * engine.SIMD_LENGTH + j) & HISTORY_MASK] += in_vec[j] * 0.5;
                }
            }
        }

        for (grains) |*g| {
            if (!g.active) {
                continue;
            }

            for (0..engine.BLOCK_LENGTH) |i| {
                const read_idx: usize = @intFromFloat(@floor(@mod(g.cursor, @as(f32, @floatFromInt(HISTORY_SIZE)))));
                const alpha = g.cursor - @floor(g.cursor);
                const sample = history[read_idx] * (1 - alpha) + history[(read_idx + 1) & HISTORY_MASK] * alpha;
                const amp = blk: {
                    const fade_param = if (g.fade > 1.0) g.fade else 1.0;
                    const fade_in = @min(@max(g.lifetime / fade_param, 0.0), 1.0);
                    const fade_out = @min(@max((g.size - g.lifetime) / fade_param, 0.0), 1.0);
                    break :blk @min(fade_in, fade_out);
                };
                inline for (0..2) |j| {
                    const current = out.get(@intCast(j), @intCast(i));
                    out.set(@intCast(j), @intCast(i), current + sample * amp);
                }

                g.cursor += g.speed;
                g.lifetime += inv_sr * 1000.0;
                if (g.lifetime > g.size) {
                    g.active = false;
                }
            }
        }

        m.head = (m.head + engine.BLOCK_LENGTH) & HISTORY_MASK;
    }
};
