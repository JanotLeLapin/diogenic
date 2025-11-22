const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (Vec) Vec;
const Eval = fn (Block) Block;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(b: Block) Block {
            var res: Block = undefined;
            for (b.channels, 0..) |channel, i| {
                for (channel, 0..) |vec, j| {
                    res.channels[i][j] = op(vec);
                }
            }
            return res;
        }
    }.eval;
}

fn generatePrimEval(comptime op: anytype) Eval {
    return generateEval(struct {
        fn eval(v: Vec) Vec {
            var res: Vec = undefined;
            for (0..block.SIMD_LENGTH) |i| {
                res[i] = op(v[i]);
            }
            return res;
        }
    }.eval);
}

fn log2(vec: Vec) Vec {
    return @log2(vec);
}

fn log10(vec: Vec) Vec {
    return @log10(vec);
}

fn logn(vec: Vec) Vec {
    return @log(vec);
}

pub fn eval(
    op: instruction.MathOperation,
    b: Block,
) Block {
    return switch (op) {
        .Log2 => generateEval(log2)(b),
        .Log10 => generateEval(log10)(b),
        .Logn => generateEval(logn)(b),
        .Atan => generatePrimEval(std.math.atan)(b),
        .Exp => generatePrimEval(std.math.exp)(b),
        .Exp2 => generatePrimEval(std.math.exp2)(b),
    };
}
