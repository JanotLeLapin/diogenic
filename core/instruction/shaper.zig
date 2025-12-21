const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

const Op = fn (Vec, Vec) Vec;

pub fn Shaper(comptime label: [:0]const u8, comptime op: Op) type {
    return struct {
        pub const name = label;

        pub const input_count = 2;
        pub const output_count = 1;

        pub fn compile(_: *Node) !@This() {
            return @This(){};
        }

        pub fn eval(
            _: *const @This(),
            inputs: []const Block,
            outputs: []Block,
            _: []f32,
            _: []Block,
        ) void {
            const mix = &inputs[0];
            const in = &inputs[1];
            const out = &outputs[0];

            for (in.channels, mix.channels, 0..) |l_chan, r_chan, i| {
                for (l_chan, r_chan, 0..) |l_vec, r_vec, j| {
                    out.channels[i][j] = op(l_vec, r_vec);
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

pub const Clamp = Shaper("clamp", clamp);
pub const Clip = Shaper("clip", clip);
pub const Diode = Shaper("diode", diode);
pub const Foldback = Shaper("foldback", foldback);
pub const Quantize = Shaper("quantize", quantize);
