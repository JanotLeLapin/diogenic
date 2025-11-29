const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (Vec, Vec, Vec) Vec;
const Eval = fn (*const Block, *const Block, *const Block, *Block) void;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(a: *const Block, l: *const Block, r: *const Block, out: *Block) void {
            for (a.channels, l.channels, r.channels, 0..) |a_channel, l_channel, r_channel, i| {
                for (a_channel, l_channel, r_channel, 0..) |a_vec, l_vec, r_vec, j| {
                    out.channels[i][j] = op(a_vec, l_vec, r_vec);
                }
            }
        }
    }.eval;
}

fn blend(a: Vec, l: Vec, r: Vec) Vec {
    const clamped = @min(@as(Vec, @splat(1.0)), @max(@as(Vec, @splat(0.0)), a));
    return (@as(Vec, @splat(1.0)) - clamped) * l + clamped * r;
}

fn mixer(a: Vec, l: Vec, r: Vec) Vec {
    const norm = a * @as(Vec, @splat(std.math.pi / 2.0));
    return @cos(norm) * l + @sin(norm) * r;
}

pub fn eval(
    op: instruction.MixOperation,
    a: *const Block,
    l: *const Block,
    r: *const Block,
    out: *Block,
) void {
    switch (op) {
        .Blend => generateEval(blend)(a, l, r, out),
        .Mixer => generateEval(mixer)(a, l, r, out),
    }
}
