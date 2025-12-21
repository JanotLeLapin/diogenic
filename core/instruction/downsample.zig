const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Downsample = struct {
    pub const name = "downsample!";

    pub const input_count = 2;
    pub const output_count = 1;
    pub const state_count = 2;

    pub const args: []const meta.Arg = &.{
        .{ .name = "sample-rate", .description = "target sample rate" },
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
        _: []Block,
    ) void {
        const target_sr = &inputs[0];
        const in = &inputs[1];
        const out = &outputs[0];
        const latest_sample = &state[0];
        const clock = &state[1];

        for (&target_sr.channels, in.channels, &out.channels) |*target_chan, in_chan, *out_chan| {
            for (target_chan, in_chan, out_chan) |*target_vec, in_vec, *out_vec| {
                for (0..engine.SIMD_LENGTH) |i| {
                    if (clock.* <= 0.0) {
                        latest_sample.* = in_vec[i];
                        clock.* += 1.0;
                    }

                    clock.* -= @min(@max(target_vec[i], 0.0), sr) / sr;
                    out_vec[i] = latest_sample.*;
                }
            }
        }
    }
};
