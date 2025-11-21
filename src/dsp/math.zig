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
    };
}
