const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (Vec, Vec) Vec;
const Eval = fn (*const Block, *const Block, *Block) void;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(left: *const Block, right: *const Block, out: *Block) void {
            for (left.channels, right.channels, 0..) |l_channel, r_channel, i| {
                for (l_channel, r_channel, 0..) |l_vec, r_vec, j| {
                    out.channels[i][j] = op(l_vec, r_vec);
                }
            }
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

inline fn cmp(mask: @Vector(block.SIMD_LENGTH, bool)) Vec {
    return @select(f32, mask, @as(Vec, @splat(0.0)), @as(Vec, @splat(1.0)));
}

fn lt(left: Vec, right: Vec) Vec {
    return cmp(left < right);
}

fn leq(left: Vec, right: Vec) Vec {
    return cmp(left <= right);
}

fn gt(left: Vec, right: Vec) Vec {
    return cmp(left > right);
}

fn geq(left: Vec, right: Vec) Vec {
    return cmp(left >= right);
}

pub fn eval(
    op: instruction.ArithmeticOperation,
    left: *const Block,
    right: *const Block,
    out: *Block,
) void {
    switch (op) {
        .Add => generateEval(add)(left, right, out),
        .Sub => generateEval(sub)(left, right, out),
        .Mul => generateEval(mul)(left, right, out),
        .Div => generateEval(div)(left, right, out),
        .Lt => generateEval(lt)(left, right, out),
        .Leq => generateEval(leq)(left, right, out),
        .Gt => generateEval(gt)(left, right, out),
        .Geq => generateEval(geq)(left, right, out),
    }
}
