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
    pub const description = "reduce the sample rate";

    pub const state_count = 2;

    pub const args: []const meta.Arg = &.{
        .{ .name = "in", .description = "input signal" },
        .{ .name = "sample-rate", .description = "target sample rate" },
    };

    pub fn compile(_: engine.CompileData) !@This() {
        return @This(){};
    }

    pub fn eval(_: *const @This(), d: engine.EvalData) void {
        const target_sr = &d.inputs[0];
        const in = &d.inputs[1];
        const latest_sample = &d.state[0];
        const clock = &d.state[1];

        for (&target_sr.channels, in.channels, &d.output.channels) |*target_chan, in_chan, *out_chan| {
            for (target_chan, in_chan, out_chan) |*target_vec, in_vec, *out_vec| {
                for (0..engine.SIMD_LENGTH) |i| {
                    if (clock.* <= 0.0) {
                        latest_sample.* = in_vec[i];
                        clock.* += 1.0;
                    }

                    clock.* -= @min(@max(target_vec[i], 0.0), d.sample_rate) / d.sample_rate;
                    out_vec[i] = latest_sample.*;
                }
            }
        }
    }
};
