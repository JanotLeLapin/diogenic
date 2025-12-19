const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (Vec) Vec;

pub fn Math(comptime label: [:0]const u8, comptime op: Op) type {
    return struct {
        pub const name = label;

        pub fn compile(_: *CompilerState, node: *Node) !@This() {
            if (node.data.list.items.len != 2) {
                return error.BadArity;
            }
            return @This(){};
        }

        pub fn eval(_: *const @This(), state: *EngineState) void {
            const in = state.popStack();
            const out = state.reserveStack();

            for (in.channels, 0..) |in_chan, i| {
                for (in_chan, 0..) |in_vec, j| {
                    out.channels[i][j] = op(in_vec);
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

fn dbToAmp(in: f32) f32 {
    return std.math.pow(f32, 10.0, in / 20.0);
}

fn ampToDb(in: f32) f32 {
    return 20.0 * @log10(in);
}

pub const Log2 = Math("log2", log2);
pub const Log10 = Math("log10", log10);
pub const Logn = Math("logn", logn);
pub const Exp2 = Math("exp2", exp2);
pub const Exp = Math("exp", exp);
pub const Atan = Math("atan", fromScalar(std.math.atan));
pub const Sigmoid = Math("sigmoid", fromScalar(sigmoid));
pub const Floor = Math("floor", floor);
pub const Ceil = Math("ceil", ceil);
pub const MidiToFreq = Math("midi->freq", midiToFreq);
pub const FreqToMidi = Math("freq->midi", freqToMidi);
pub const DbToAmp = Math("db->amp", fromScalar(dbToAmp));
pub const AmpToDb = Math("amp->db", fromScalar(ampToDb));
