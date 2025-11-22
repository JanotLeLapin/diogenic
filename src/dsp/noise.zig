const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const Block = block.Block;
const Vec = block.Vec;

pub fn eval(
    op: instruction.NoiseOperation,
    out: *Block,
) void {
    switch (op) {
        .White => {
            var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.nanoTimestamp())));
            var rand = prng.random();
            for (&out.channels) |*channel| {
                for (channel) |*vec| {
                    for (0..block.SIMD_LENGTH) |i| {
                        vec[i] = rand.floatNorm(f32);
                    }
                }
            }
        },
    }
}
