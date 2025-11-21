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

fn quantize(bits: Vec, input: Vec) Vec {
    const levels = @exp2(bits);
    const normalized = (input + @as(Vec, @splat(1.0))) * @as(Vec, @splat(0.5));
    const quantized = @floor(normalized * levels) / (levels - @as(Vec, @splat(1.0)));
    return quantized * @as(Vec, @splat(2.0)) - @as(Vec, @splat(1.0));
}

pub fn eval(
    op: instruction.ShaperOperation,
    mix: Block,
    input: Block,
) Block {
    return switch (op) {
        .Quantize => generateEval(quantize)(mix, input),
    };
}
