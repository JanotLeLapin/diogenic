const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (Vec, Vec) Vec;
const Eval = fn (*const Block, *const Block, *Block) void;

inline fn clamp_2pi(a: Vec) Vec {
    return @min(@as(Vec, @splat(1.0)), @max(@as(Vec, @splat(0.0)), a));
}

pub fn evalPan(
    mix: *const Block,
    input: *const Block,
    out: *Block,
) void {
    for (mix.channels[0], input.channels[0], 0..) |mix_vec, input_vec, i| {
        const norm = clamp_2pi(mix_vec) * @as(Vec, @splat(std.math.pi / 2.0));
        const g = @cos(norm);
        out.channels[0][i] = input_vec * g;
    }
    for (mix.channels[1], input.channels[1], 0..) |mix_vec, input_vec, i| {
        const norm = clamp_2pi(mix_vec) * @as(Vec, @splat(std.math.pi / 2.0));
        const g = @sin(norm);
        out.channels[1][i] = input_vec * g;
    }
}
