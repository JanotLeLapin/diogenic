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

const Meta = struct {
    counter: u32,
    head: u32,
    grains_to_register: f32,
};

const GrainMeta = struct {
    active: bool,
    lifetime: f32,
    cursor: f32,
    speed: f32,
    size: f32,
    fade: f32,
};

const State = struct {
    history: [][2]f32,
    grains: []GrainMeta,
    meta: Meta,
};

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

    pub const args: []const meta.Arg = &.{
        .{ .name = "in", .description = "input signal" },
        .{ .name = "density", .description = "grain density, in grains per second", .default = 10.0 },
        .{ .name = "size", .description = "grain size, in milliseconds", .default = 100.0 },
        .{ .name = "speed", .description = "grain playback speed", .default = 1.0 },
        .{ .name = "position", .description = "grain spawn position, 0 = tail, 1 = head", .default = 0.5 },
        .{ .name = "fade", .description = "grain fade in/out, in milliseconds", .default = 10.0 },
    };

    state: *State,

    pub fn compile(d: engine.CompileData) !@This() {
        const state = try d.alloc.create(State);
        state.* = .{
            .history = try d.alloc.alloc([2]f32, HISTORY_SIZE),
            .grains = try d.alloc.alloc(GrainMeta, MAX_POLYPHONY),
            .meta = .{
                .counter = 0,
                .head = 0,
                .grains_to_register = 0.0,
            },
        };

        return @This(){
            .state = state,
        };
    }

    pub fn eval(self: *const @This(), d: engine.EvalData) void {
        const inv_sr = 1.0 / d.sample_rate;

        const in = &d.inputs[0];
        const density = &d.inputs[1];
        const size = &d.inputs[2];
        const speed = &d.inputs[3];
        const position = &d.inputs[4];
        const fade = &d.inputs[5];

        const state = self.state;
        const history = state.history;
        const grains = state.grains;

        const history_len = @min(state.meta.counter, HISTORY_SIZE);
        const history_len_f: f32 = @floatFromInt(history_len);
        const head_f: f32 = @floatFromInt(state.meta.head);
        const size_f: f32 = @floatFromInt(HISTORY_SIZE);

        for (
            density.channels[0],
            size.channels[0],
            speed.channels[0],
            position.channels[0],
            fade.channels[0],
        ) |density_vec, size_vec, speed_vec, position_vec, fade_vec| {
            for (0..engine.SIMD_LENGTH) |i| {
                state.meta.grains_to_register += inv_sr * density_vec[i];

                while (state.meta.grains_to_register > 1.0) {
                    state.meta.grains_to_register -= 1.0;

                    const g = getGrainSlot(grains) orelse continue;

                    const lookback = (1.0 - position_vec[i]) * history_len_f;
                    g.active = true;
                    g.lifetime = 1.0;
                    g.cursor = @mod(head_f - lookback, size_f);
                    g.speed = @max(speed_vec[i], 0.2);
                    g.size = @max(size_vec[i], 1.0);
                    g.fade = @max(fade_vec[i], 0.0);
                }
            }
        }

        for (in.channels, &d.output.channels, 0..) |in_chan, *out_chan, j| {
            for (in_chan, out_chan, 0..) |in_vec, *out_vec, i| {
                out_vec.* = @splat(0.0);
                inline for (0..engine.SIMD_LENGTH) |k| {
                    history[(state.meta.head + i * engine.SIMD_LENGTH + k) & HISTORY_MASK][j] = in_vec[k];
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
                const amp = blk: {
                    const fade_param = if (g.fade > 1.0) g.fade else 1.0;
                    const fade_in = @min(@max(g.lifetime / fade_param, 0.0), 1.0);
                    const fade_out = @min(@max((g.size - g.lifetime) / fade_param, 0.0), 1.0);
                    break :blk @min(fade_in, fade_out);
                };
                inline for (0..2) |j| {
                    const sample = history[read_idx][j] * (1 - alpha) + history[(read_idx + 1) & HISTORY_MASK][j] * alpha;
                    const current = d.output.get(@intCast(j), @intCast(i));
                    d.output.set(@intCast(j), @intCast(i), current + sample * amp);
                }

                g.cursor += g.speed;
                g.lifetime += inv_sr * 1000.0;
                if (g.lifetime > g.size) {
                    g.active = false;
                }
            }
        }

        state.meta.head = (state.meta.head + engine.BLOCK_LENGTH) & HISTORY_MASK;
        state.meta.counter = @min(HISTORY_SIZE, state.meta.counter + engine.BLOCK_LENGTH);
    }
};
