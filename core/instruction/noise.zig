const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Noise = struct {
    pub const name = "noise!";

    pub const input_count = 0;
    pub const output_count = 1;
    pub const state_count = 2;

    pub fn compile(_: *Node) !@This() {
        return @This(){};
    }

    pub fn eval(
        _: *const @This(),
        _: f32,
        _: []const Block,
        outputs: []Block,
        state: []f32,
        _: []Block,
    ) void {
        const seed: u64 = (@as(u64, @intCast(@as(u32, @bitCast(state[0]))))) << 8 | @as(u32, @bitCast(state[1]));
        var prng = std.Random.DefaultPrng.init(seed);
        var rand = prng.random();

        const next_seed: u64 = rand.int(u64);
        state[0] = @bitCast(@as(u32, @truncate(next_seed >> 32)));
        state[1] = @bitCast(@as(u32, @truncate(next_seed)));

        const out = &outputs[0];
        for (&out.channels) |*out_chan| {
            for (out_chan) |*out_vec| {
                for (0..engine.SIMD_LENGTH) |i| {
                    out_vec[i] = rand.floatNorm(f32);
                }
            }
        }
    }
};
