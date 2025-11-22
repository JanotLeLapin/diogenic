const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (Vec) Vec;
const Eval = fn (*const Block, *Block) void;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(in: *const Block, out: *Block) void {
            for (in.channels, 0..) |channel, i| {
                for (channel, 0..) |vec, j| {
                    out.channels[i][j] = op(vec);
                }
            }
        }
    }.eval;
}

fn generatePrimEval(comptime op: anytype) Eval {
    return generateEval(struct {
        fn eval(in: Vec) Vec {
            var res: Vec = undefined;
            for (0..block.SIMD_LENGTH) |i| {
                res[i] = op(in[i]);
            }
            return res;
        }
    }.eval);
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

pub fn eval(
    op: instruction.MathOperation,
    in: *const Block,
    out: *Block,
) void {
    switch (op) {
        .Log2 => generateEval(log2)(in, out),
        .Log10 => generateEval(log10)(in, out),
        .Logn => generateEval(logn)(in, out),
        .Atan => generatePrimEval(std.math.atan)(in, out),
        .Exp => generatePrimEval(std.math.exp)(in, out),
        .Exp2 => generatePrimEval(std.math.exp2)(in, out),
    }
}
