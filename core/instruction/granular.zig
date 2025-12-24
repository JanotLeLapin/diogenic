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
const HISTORY_SIZE: usize = 48000 * 5 / engine.BLOCK_LENGTH;

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
};

inline fn floatCount(comptime T: type) usize {
    return (@sizeOf(T) + @sizeOf(f32) - 1) / @sizeOf(f32);
}

const META_FLOATS = floatCount(Meta);
const GRAIN_META_FLOATS = floatCount(GrainMeta);

fn getMeta(state: []f32) *Meta {
    const bytes = std.mem.sliceAsBytes(state[0..META_FLOATS]);
    return &std.mem.bytesAsSlice(Meta, bytes)[0];
}

fn getGrainMeta(state: []f32) []GrainMeta {
    const bytes = std.mem.sliceAsBytes(state[META_FLOATS .. META_FLOATS + (MAX_POLYPHONY * GRAIN_META_FLOATS)]);
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

    pub const input_count = 4;
    pub const output_count = 1;
    pub const state_count = META_FLOATS + MAX_POLYPHONY * GRAIN_META_FLOATS;
    pub const register_count = HISTORY_SIZE;

    pub const args: []const meta.Arg = &.{
        .{ .name = "density", .description = "grain density, in grains per second", .default = 0.0 },
        .{ .name = "size", .description = "grain size, in milliseconds", .default = 100.0 },
        .{ .name = "speed", .description = "grain playback speed", .default = 0.0 },
        .{ .name = "in", .description = "input signal" },
    };

    pub fn compile(_: *Node) !@This() {
        return @This(){};
    }

    pub fn eval(
        _: *const @This(),
        sr: f32,
        inputs: []const Block,
        outputs: []Block,
        state: []f32,
        reg: []Block,
    ) void {
        const density = &inputs[0];
        const size = &inputs[1];
        const speed = &inputs[2];
        const in = &inputs[3];
        const out = &outputs[0];

        const grains = getGrainMeta(state);
        const m = getMeta(state);

        reg[m.head] = in.*;

        m.grains_to_register += (@as(f32, @floatFromInt(engine.BLOCK_LENGTH)) / sr) * density.get(0, 0);
        while (m.grains_to_register > 1.0) {
            m.grains_to_register -= 1.0;

            const g = getGrainSlot(grains) orelse continue;
            g.active = true;
            g.lifetime = 1.0;
            g.cursor = @floatFromInt(m.head);
            g.size = size.get(0, 0);
            g.speed = speed.get(0, 0);
            // TODO: clamp size or speed to avoid "overflow"
        }

        for (&out.channels) |*out_chan| {
            for (out_chan) |*out_vec| {
                out_vec.* = @splat(0.0);
            }
        }

        for (grains) |*g| {
            if (!g.active) {
                continue;
            }

            const read_idx: usize = @intFromFloat(@floor(@mod(g.cursor, @as(f32, @floatFromInt(HISTORY_SIZE)))));
            const b = &reg[read_idx];

            for (b.channels, &out.channels) |b_chan, *out_chan| {
                for (b_chan, out_chan) |b_vec, *out_vec| {
                    out_vec.* += b_vec;
                }
            }

            g.cursor += g.speed;
            g.lifetime += 1.0;
            if (g.lifetime > g.size) {
                g.active = false;
            }
        }

        m.head = (m.head + 1) % @as(u32, @intCast(HISTORY_SIZE));
    }
};
