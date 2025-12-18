const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Noise = struct {
    pub const name = "noise";

    pub fn compile(_: *CompilerState, _: *Node) !@This() {
        return @This(){};
    }

    pub fn eval(_: *const @This(), state: *EngineState) void {
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
        var rand = prng.random();

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
