// all the parameters I've found from this repo:
// https://github.com/MajenkoLibraries/Biquad
// thanks majenko <3

const std = @import("std");

const engine = @import("../../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("../meta.zig");

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
        pub const description = "biquadratic filter";

        pub const input_count = 4;
        pub const output_count = 1;
        pub const state_count = 4;

        pub const args: []const meta.Arg = &.{
            .{ .name = "freq" },
            .{ .name = "q", .description = "quality factor", .default = 0.707 },
            .{ .name = "g", .description = "gain factor", .default = 1.0 },
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
            const fc = &inputs[0];
            const q = &inputs[1];
            const g = &inputs[2];
            const in = &inputs[3];
            const out = &outputs[0];
            const tmp = state[0..4];

            for (fc.channels, q.channels, g.channels, in.channels, &out.channels, 0..) |fc_chan, q_chan, g_chan, in_chan, *out_chan, i| {
                for (fc_chan, q_chan, g_chan, in_chan, 0..) |fc_vec, q_vec, g_vec, in_vec, j| {
                    var p: Params = undefined;
                    const nfc = fc_vec / @as(Vec, @splat(sr));
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

fn band(_: Vec, q: Vec, _: Vec, k: Vec, p: *Params) void {
    const norm = @as(Vec, @splat(1)) / (@as(Vec, @splat(1)) + k / q + k * k);
    p.a0 = k / q * norm;
    p.a1 = @splat(0);
    p.a2 = @as(Vec, @splat(-1)) * p.a0;
    p.b1 = @as(Vec, @splat(2)) * (k / q - @as(Vec, @splat(1))) * norm;
    p.b2 = (@as(Vec, @splat(1)) - k / q + k * k) * norm;
}

fn notch(_: Vec, q: Vec, _: Vec, k: Vec, p: *Params) void {
    const norm = @as(Vec, @splat(1)) / (@as(Vec, @splat(1)) + k / q + k * k);
    p.a0 = (@as(Vec, @splat(1)) + k * k) + norm;
    p.a1 = @as(Vec, @splat(2)) * (k * k - @as(Vec, @splat(1))) * norm;
    p.a2 = p.a0;
    p.b1 = p.a1;
    p.b2 = (@as(Vec, @splat(1)) - k / q + k * k) * norm;
}

pub const High = Biquad("b-highpass!", high);
pub const Low = Biquad("b-lowpass!", low);
pub const Band = Biquad("b-bandpass!", band);
pub const Notch = Biquad("b-notch!", notch);
