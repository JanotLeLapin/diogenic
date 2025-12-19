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

    state_idx: usize,

    pub fn compile(state: *CompilerState, node: *Node) !@This() {
        if (node.data.list.items.len != 1) {
            return error.BadArity;
        }
        const self = @This(){ .state_idx = state.state_index };
        state.state_index += 1;
        return self;
    }

    pub fn eval(self: *const @This(), state: *EngineState) void {
        const seed: u64 = (@as(u64, @intCast(@as(u32, @bitCast(state.state[self.state_idx]))))) << 8 | @as(u32, @bitCast(state.state[self.state_idx + 1]));
        var prng = std.Random.DefaultPrng.init(seed);
        var rand = prng.random();

        const next_seed: u64 = rand.int(u64);
        state.state[self.state_idx] = @bitCast(@as(u32, @truncate(next_seed >> 32)));
        state.state[self.state_idx + 1] = @bitCast(@as(u32, @truncate(next_seed)));

        const out = state.reserveStack();
        for (&out.channels) |*out_chan| {
            for (out_chan) |*out_vec| {
                for (0..engine.SIMD_LENGTH) |i| {
                    out_vec[i] = rand.floatNorm(f32);
                }
            }
        }
    }
};
