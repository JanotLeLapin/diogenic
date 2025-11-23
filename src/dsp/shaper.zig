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

fn clip(threshold: Vec, input: Vec) Vec {
    const abs = @abs(threshold);
    const min = @min(input, abs);
    return @max(min, (@as(Vec, @splat(-1.0)) * abs));
}

fn diode(threshold: Vec, input: Vec) Vec {
    const floor = threshold - @as(Vec, @splat(1));
    const ceil = threshold + @as(Vec, @splat(1));
    return @min(@max(input, floor), ceil);
}

fn quantize(bits: Vec, input: Vec) Vec {
    const levels = @exp2(bits);
    const normalized = (input + @as(Vec, @splat(1.0))) * @as(Vec, @splat(0.5));
    const quantized = @floor(normalized * levels) / (levels - @as(Vec, @splat(1.0)));
    return quantized * @as(Vec, @splat(2.0)) - @as(Vec, @splat(1.0));
}

pub fn eval(
    op: instruction.ShaperOperation,
    mix: *const Block,
    input: *const Block,
    out: *Block,
) void {
    switch (op) {
        .Clip => generateEval(clip)(mix, input, out),
        .Diode => generateEval(diode)(mix, input, out),
        .Quantize => generateEval(quantize)(mix, input, out),
    }
}
