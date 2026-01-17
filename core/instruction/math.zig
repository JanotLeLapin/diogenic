const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (Vec) Vec;

pub fn Math(
    comptime label: [:0]const u8,
    comptime custom_description: []const u8,
    comptime op: Op,
) type {
    return struct {
        pub const name = label;
        pub const description = custom_description;

        pub const args: []const meta.Arg = &.{
            .{ .name = "in" },
        };

        pub fn compile(_: engine.CompileData) !@This() {
            return @This(){};
        }

        pub fn eval(_: *const @This(), d: engine.EvalData) void {
            const in = &d.inputs[0];

            for (in.channels, 0..) |in_chan, i| {
                for (in_chan, 0..) |in_vec, j| {
                    d.output.channels[i][j] = op(in_vec);
                }
            }
        }
    };
}

pub fn fromScalar(fin: anytype) Op {
    return struct {
        fn fout(in: Vec) Vec {
            var out: Vec = undefined;
            for (0..engine.SIMD_LENGTH) |i| {
                out[i] = fin(in[i]);
            }
            return out;
        }
    }.fout;
}

fn log2(in: Vec) Vec {
    return @log2(in);
}

fn log10(in: Vec) Vec {
    return @log10(in);
}

fn logn(in: Vec) Vec {
    return @log(in);
}

fn exp2(in: Vec) Vec {
    return @exp2(in);
}

fn exp(in: Vec) Vec {
    return @exp(in);
}

fn sigmoid(in: f32) f32 {
    return 1 / (1 + std.math.exp(-in));
}

fn floor(in: Vec) Vec {
    return @floor(in);
}

fn ceil(in: Vec) Vec {
    return @ceil(in);
}

fn midiToFreq(in: Vec) Vec {
    return @as(Vec, @splat(440.0)) * @exp2((in - @as(Vec, @splat(69.0))) / @as(Vec, @splat(12.0)));
}

fn freqToMidi(in: Vec) Vec {
    return @as(Vec, @splat(69.0)) + @as(Vec, @splat(12.0)) * @log2(in / @as(Vec, @splat(440.0)));
}

fn biToUni(in: Vec) Vec {
    return @mulAdd(Vec, in, @as(Vec, @splat(0.5)), @as(Vec, @splat(0.5)));
}

fn uniToBi(in: Vec) Vec {
    return @mulAdd(Vec, in, @as(Vec, @splat(2.0)), @as(Vec, @splat(-1.0)));
}

fn dbToAmp(in: f32) f32 {
    return std.math.pow(f32, 10.0, in / 20.0);
}

fn ampToDb(in: f32) f32 {
    return 20.0 * @log10(in);
}

pub const Log2 = Math("log2", "binary logarithm", log2);
pub const Log10 = Math("log10", "decimal logarithm", log10);
pub const Logn = Math("logn", "neperian logarithm", logn);
pub const Exp2 = Math("exp2", "base-2 exponential", exp2);
pub const Exp = Math("exp", "base-e exponential", exp);

pub const Asin = Math("asin", "arc sinus", fromScalar(std.math.asin));
pub const Asinh = Math("asinh", "hyperbolic arc sinus", fromScalar(std.math.asinh));
pub const Sin = Math("sin", "sinus", fromScalar(std.math.sin));
pub const Sinh = Math("sinh", "hyperbolic sinus", fromScalar(std.math.sinh));
pub const Acos = Math("acos", "arc cosinus", fromScalar(std.math.acos));
pub const Acosh = Math("acosh", "hyperbolic arc cosinus", fromScalar(std.math.acosh));
pub const Cos = Math("cos", "cosinus", fromScalar(std.math.cos));
pub const Cosh = Math("cosh", "hyperbolic cosinus", fromScalar(std.math.cosh));
pub const Atan = Math("atan", "arc tangent", fromScalar(std.math.atan));
pub const Atanh = Math("atanh", "hyperbolic arc tangent", fromScalar(std.math.atanh));
pub const Tan = Math("tan", "tangent", fromScalar(std.math.tan));
pub const Tanh = Math("tanh", "hyperbolic tangent", fromScalar(std.math.tanh));

pub const Sigmoid = Math("sigmoid", "sigmoid", fromScalar(sigmoid));
pub const Floor = Math("floor", "floor rounding", floor);
pub const Ceil = Math("ceil", "ceil rounding", ceil);

pub const MidiToFreq = Math("midi->freq", "midi pitch to frequency unit translation", midiToFreq);
pub const FreqToMidi = Math("freq->midi", "frequency to midi pitch unit translation", freqToMidi);
pub const BiToUni = Math("bi->uni", "bipolar [-1; 1] to unipolar [0; 1] signal remapping", biToUni);
pub const UniToBi = Math("uni->bi", "unipolar [0; 1] to bipolar [-1; 1] signal remapping", uniToBi);
pub const DbToAmp = Math("db->amp", "decibel to amplitude unit translation", fromScalar(dbToAmp));
pub const AmpToDb = Math("amp->db", "amplitude to decibel unit translation", fromScalar(ampToDb));
