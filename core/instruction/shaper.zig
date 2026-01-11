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
    comptime t_name: []const u8,
    comptime t_desc: []const u8,
    comptime op: Op,
) type {
    return struct {
        pub const name = label;
        pub const description = custom_description;

        pub const args: []const meta.Arg = &.{
            .{ .name = "in", .description = "input signal" },
            .{ .name = t_name, .description = t_desc },
        };

        pub fn compile(_: engine.CompileData) !@This() {
            return @This(){};
        }

        pub fn eval(_: *const @This(), d: engine.EvalData) void {
            const in = &d.inputs[0];
            const t = &d.inputs[1];

            for (t.channels, in.channels, 0..) |t_chan, in_chan, i| {
                for (t_chan, in_chan, 0..) |t_vec, in_vec, j| {
                    d.output.channels[i][j] = op(t_vec, in_vec);
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

pub const Clamp = Shaper(
    "clamp",
    "clamps the signal between `t-1` and `t+1`",
    "threshold",
    "`t`",
    clamp,
);
pub const Clip = Shaper(
    "clip",
    "clamps the signal between `-t` and `+t`",
    "threshold",
    "`t`",
    clip,
);
pub const Diode = Shaper(
    "diode",
    "diode wave shaper",
    "threshold",
    "`t`",
    diode,
);
pub const Foldback = Shaper(
    "foldback",
    "foldback wave shaper",
    "threshold",
    "`t`",
    foldback,
);
pub const Quantize = Shaper(
    "quantize",
    "quantizer",
    "bits",
    "level of precision, roughly equates to the bits used to encode the amplitude. Typically ranges between 0.0 and 32.0.",
    quantize,
);
