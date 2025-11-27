const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

const Op = fn (f32) f32;
const Eval = fn (*const Block, *const Block, *f32, *Block) void;

fn generateEval(comptime op: Op) Eval {
    return struct {
        fn eval(freq: *const Block, pm: *const Block, phase: *f32, out: *Block) void {
            var acc: f32 = 0.0;
            for (freq.channels, pm.channels, 0..) |freq_channel, pm_channel, i| {
                acc = phase.*;
                for (freq_channel, pm_channel, 0..) |freq_vec, pm_vec, j| {
                    const inc_vec = freq_vec / @as(Vec, @splat(48000));
                    for (0..block.SIMD_LENGTH) |k| {
                        const inc = inc_vec[k];

                        const radians = std.math.pi * 2 * acc;
                        out.channels[i][j][k] = op(radians + pm_vec[k]);

                        acc += inc;
                        acc -= @floor(acc);
                    }
                }
            }

            phase.* = acc;
        }
    }.eval;
}

fn sawtooth(p: f32) f32 {
    return p / std.math.pi - 1.0;
}

fn sine(p: f32) f32 {
    return std.math.sin(p);
}

fn square(p: f32) f32 {
    return @floor(p / std.math.pi) * 2.0 - 1.0;
}

pub fn eval(
    op: instruction.OscOperationType,
    freq: *const Block,
    pm: *const Block,
    phase: *f32,
    out: *Block,
) void {
    switch (op) {
        .Sawtooth => generateEval(sawtooth)(freq, pm, phase, out),
        .Sine => generateEval(sine)(freq, pm, phase, out),
        .Square => generateEval(square)(freq, pm, phase, out),
    }
}
