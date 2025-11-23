const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Params = struct {
    a0: Vec,
    a1: Vec,
    a2: Vec,
    b1: Vec,
    b2: Vec,

    fn init(p: *Params, t: instruction.FilterOperationType, fc: Vec, q: Vec, g: Vec) void {
        _ = g;
        const nfc = fc / @as(Vec, @splat(48000));
        const k = @tan(@as(Vec, @splat(std.math.pi)) * nfc);
        switch (t) {
            .High => {
                const norm = @as(Vec, @splat(1)) / (@as(Vec, @splat(1)) + k / q + k * k);
                p.a0 = @as(Vec, @splat(-2)) * norm;
                p.a1 = @as(Vec, @splat(-2)) * p.a0;
                p.a2 = p.a0;
                p.b1 = @as(Vec, @splat(2)) * (k * k - @as(Vec, @splat(1))) * norm;
                p.b2 = (@as(Vec, @splat(1)) - k / q + k * k) * norm;
            },
            .Low => {
                const norm = @as(Vec, @splat(1)) / (@as(Vec, @splat(1)) + k / q + k * k);
                p.a0 = k * k * norm;
                p.a1 = @as(Vec, @splat(2)) * p.a0;
                p.a2 = p.a0;
                p.b1 = @as(Vec, @splat(2)) * (k * k - @as(Vec, @splat(1))) * norm;
                p.b2 = (@as(Vec, @splat(1)) - k / q + k * k) * norm;
            },
        }
    }
};

fn process(p: *Params, in: Vec, z: [2]*f32) Vec {
    var out: Vec = undefined;
    for (0..block.SIMD_LENGTH) |i| {
        out[i] = in[i] * p.a0[i] + z[0].*;
        z[0].* = in[i] * p.a1[i] + z[1].* - p.b1[i] * out[i];
        z[1].* = in[i] * p.a2[i] - p.b2[i] * out[i];
    }
    return out;
}

pub fn eval(
    op: instruction.FilterOperation,
    tmp: [2][2]*f32,
    fc: *const Block,
    q: *const Block,
    g: *const Block,
    in: *const Block,
    out: *Block,
) void {
    for (fc.channels, q.channels, g.channels, in.channels, &out.channels, 0..) |fc_channel, q_channel, g_channel, in_channel, *out_channel, i| {
        for (fc_channel, q_channel, g_channel, in_channel, 0..) |fc_vec, q_vec, g_vec, in_vec, j| {
            var p: Params = undefined;
            p.init(op.t, fc_vec, q_vec, g_vec);
            out_channel[j] = process(&p, in_vec, tmp[i]);
        }
    }
}
