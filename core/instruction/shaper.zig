const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

const Op = fn (Vec, Vec) Vec;

pub fn Shaper(
    comptime label: [:0]const u8,
    comptime custom_description: []const u8,
    comptime op: Op,
) type {
    return struct {
        pub const name = label;
        pub const description = custom_description;

        pub const args: []const meta.Arg = &.{
            .{ .name = "threshold" },
            .{ .name = "in", .description = "input signal" },
        };

        pub fn compile(_: engine.CompileData) !@This() {
            return @This(){};
        }

        pub fn eval(_: *const @This(), d: engine.EvalData) void {
            const mix = &d.inputs[0];
            const in = &d.inputs[1];

            for (in.channels, mix.channels, 0..) |l_chan, r_chan, i| {
                for (l_chan, r_chan, 0..) |l_vec, r_vec, j| {
                    d.output.channels[i][j] = op(l_vec, r_vec);
                }
            }
        }
    };
}

fn clamp(threshold: Vec, input: Vec) Vec {
    const floor = threshold - @as(Vec, @splat(1));
    const ceil = threshold + @as(Vec, @splat(1));
    return @min(@max(input, floor), ceil);
}

fn clip(threshold: Vec, input: Vec) Vec {
    const abs = @abs(threshold);
    const min = @min(input, abs);
    return @max(min, (@as(Vec, @splat(-1.0)) * abs));
}

fn diode(threshold: Vec, input: Vec) Vec {
    return @max(input - threshold, @as(Vec, @splat(0)));
}

fn foldback(threshold: Vec, input: Vec) Vec {
    const coef = @as(Vec, @splat(4.0)) * threshold;
    const period = (input / coef) + @as(Vec, @splat(0.25));
    return coef * (@abs(period - @round(period)) - @as(Vec, @splat(0.25)));
}

fn quantize(bits: Vec, input: Vec) Vec {
    const levels = @exp2(bits);
    const normalized = (input + @as(Vec, @splat(1.0))) * @as(Vec, @splat(0.5));
    const quantized = @floor(normalized * levels) / (levels - @as(Vec, @splat(1.0)));
    return quantized * @as(Vec, @splat(2.0)) - @as(Vec, @splat(1.0));
}

pub const Clamp = Shaper("clamp", "clamps the signal between `t-1` and `t+1`", clamp);
pub const Clip = Shaper("clip", "clamps the signal between `-t` and `+t`", clip);
pub const Diode = Shaper("diode", "diode wave shaper", diode);
pub const Foldback = Shaper("foldback", "foldback wave shaper", foldback);
pub const Quantize = Shaper("quantize", "quantizer wave shaper, smaller threshold means worse quality", quantize);
