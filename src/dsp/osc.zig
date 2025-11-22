const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (f32) f32;
const Eval = fn (Block, Block, *f32) Block;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(freq: Block, pm: Block, phase: *f32) Block {
            var res: Block = undefined;
            var acc: f32 = 0.0;
            for (freq.channels, pm.channels, 0..) |freq_channel, pm_channel, i| {
                acc = phase.*;
                for (freq_channel, pm_channel, 0..) |freq_vec, pm_vec, j| {
                    const inc_vec = freq_vec / @as(Vec, @splat(48000));
                    for (0..block.SIMD_LENGTH) |k| {
                        const inc = inc_vec[k];

                        const radians = std.math.pi * 2 * acc;
                        res.channels[i][j][k] = op(radians + pm_vec[k]);

                        acc += inc;
                        acc -= @floor(acc);
                    }
                }
            }

            phase.* = acc;

            return res;
        }
    }.eval;
}

const inv_2_pi = (1.0 / (2.0 * std.math.pi));

fn sawtooth(p: f32) f32 {
    return p * inv_2_pi - 1.0;
}

fn sine(p: f32) f32 {
    return std.math.sin(p);
}

fn square(p: f32) f32 {
    if (p < std.math.pi) {
        return -1.0;
    } else {
        return 1.0;
    }
}

pub fn eval(
    op: instruction.OscOperationType,
    freq: Block,
    pm: Block,
    phase: *f32,
) Block {
    return switch (op) {
        .Sawtooth => generateEval(sawtooth)(freq, pm, phase),
        .Sine => generateEval(sine)(freq, pm, phase),
        .Square => generateEval(square)(freq, pm, phase),
    };
}
