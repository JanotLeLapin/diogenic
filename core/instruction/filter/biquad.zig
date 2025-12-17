// all the parameters I've found from this repo:
// https://github.com/MajenkoLibraries/Biquad
// thanks majenko <3

const std = @import("std");

const compiler = @import("../../compiler.zig");
const CompilerState = compiler.CompilerState;

const engine = @import("../../engine.zig");
const Block = engine.Block;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../../parser.zig");
const Node = parser.Node;

const Params = struct {
    a0: Vec,
    a1: Vec,
    a2: Vec,
    b1: Vec,
    b2: Vec,
};

pub const OpInit = fn (fc: Vec, q: Vec, g: Vec, k: Vec, *Params) void;

inline fn process(p: *Params, in: Vec, z: []f32) Vec {
    var out: Vec = undefined;
    for (0..engine.SIMD_LENGTH) |i| {
        out[i] = in[i] * p.a0[i] + z[0];
        z[0] = in[i] * p.a1[i] + z[1] - p.b1[i] * out[i];
        z[1] = in[i] * p.a2[i] - p.b2[i] * out[i];
    }
    return out;
}

pub fn Biquad(comptime label: [:0]const u8, comptime init: OpInit) type {
    return struct {
        pub const name = label;

        tmp_index: usize,

        pub fn compile(state: *CompilerState, _: *Node) !@This() {
            const self = @This(){
                .tmp_index = state.state_index,
            };
            state.state_index += 4;
            return self;
        }

        pub fn eval(self: *const @This(), state: *EngineState) void {
            const in = state.popStack();
            const g = state.popStack();
            const q = state.popStack();
            const fc = state.popStack();
            const out = state.reserveStack();
            const tmp = state.state[self.tmp_index .. self.tmp_index + 4];

            for (fc.channels, q.channels, g.channels, in.channels, &out.channels, 0..) |fc_chan, q_chan, g_chan, in_chan, *out_chan, i| {
                for (fc_chan, q_chan, g_chan, in_chan, 0..) |fc_vec, q_vec, g_vec, in_vec, j| {
                    var p: Params = undefined;
                    const nfc = fc_vec / @as(Vec, @splat(state.sr));
                    const k = @tan(@as(Vec, @splat(std.math.pi)) * nfc);
                    init(fc_vec, q_vec, g_vec, k, &p);

                    const o = i * 2;
                    out_chan[j] = process(&p, in_vec, tmp[o .. o + 2]);
                }
            }
        }
    };
}

fn high(_: Vec, q: Vec, _: Vec, k: Vec, p: *Params) void {
    const norm = @as(Vec, @splat(1)) / (@as(Vec, @splat(1)) + k / q + k * k);
    p.a0 = @as(Vec, @splat(-2)) * norm;
    p.a1 = @as(Vec, @splat(-2)) * p.a0;
    p.a2 = p.a0;
    p.b1 = @as(Vec, @splat(2)) * (k * k - @as(Vec, @splat(1))) * norm;
    p.b2 = (@as(Vec, @splat(1)) - k / q + k * k) * norm;
}

fn low(_: Vec, q: Vec, _: Vec, k: Vec, p: *Params) void {
    const norm = @as(Vec, @splat(1)) / (@as(Vec, @splat(1)) + k / q + k * k);
    p.a0 = k * k * norm;
    p.a1 = @as(Vec, @splat(2)) * p.a0;
    p.a2 = p.a0;
    p.b1 = @as(Vec, @splat(2)) * (k * k - @as(Vec, @splat(1))) * norm;
    p.b2 = (@as(Vec, @splat(1)) - k / q + k * k) * norm;
}

pub const High = Biquad("b-highpass", high);
pub const Low = Biquad("b-lowpass", low);
