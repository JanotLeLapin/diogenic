const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (Vec, Vec) Vec;
const Eval = fn (Block, Block) Block;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(left: Block, right: Block) Block {
            var res: Block = undefined;
            for (left.channels, right.channels, 0..) |l_channel, r_channel, i| {
                for (l_channel, r_channel, 0..) |l_vec, r_vec, j| {
                    res.channels[i][j] = op(l_vec, r_vec);
                }
            }
            return res;
        }
    }.eval;
}

fn add(left: Vec, right: Vec) Vec {
    return left + right;
}

fn sub(left: Vec, right: Vec) Vec {
    return left - right;
}

fn mul(left: Vec, right: Vec) Vec {
    return left * right;
}

fn div(left: Vec, right: Vec) Vec {
    return left / right;
}

pub fn eval(
    op: instruction.ArithmeticOperation,
    left: Block,
    right: Block,
) Block {
    return switch (op) {
        .Add => generateEval(add)(left, right),
        .Sub => generateEval(sub)(left, right),
        .Mul => generateEval(mul)(left, right),
        .Div => generateEval(div)(left, right),
    };
}
