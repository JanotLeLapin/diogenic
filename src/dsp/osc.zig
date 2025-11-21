const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const s_two: Vec = @splat(2);
const s_pi: Vec = @splat(std.math.pi);
const s_sr: Vec = @splat(48000); // FIXME: hardcoded sample rate

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
                    const inc = s_two * s_pi * freq_vec / s_sr;
                    for (0..8) |k| { // FIXME: hardcoded simd len
                        acc += inc[k];

                        if (acc >= 2.0 * std.math.pi) {
                            acc -= 2.0 * std.math.pi;
                        }

                        res.channels[i][j][k] = op(acc + pm_vec[k]);
                    }
                }
            }

            phase.* = acc;

            return res;
        }
    }.eval;
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
        .Sine => generateEval(sine)(freq, pm, phase),
        .Square => generateEval(square)(freq, pm, phase),
    };
}
