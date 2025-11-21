const std = @import("std");

const instruction = @import("instruction.zig");

const block = @import("dsp/block.zig");
const engine = @import("dsp/engine.zig");

const sndfile = @cImport({
    @cInclude("sndfile.h");
});

pub fn render_wav32(
    filename: []const u8,
    instructions: std.ArrayList(instruction.Instruction),
    e: *engine.Engine,
    block_count: usize,
    buf_allocator: std.mem.Allocator,
    stack_allocator: std.mem.Allocator,
) !void {
    var buf: [block.BLOCK_LENGTH * 2]f32 = undefined;

    var sfinfo = sndfile.SF_INFO{
        .frames = @intCast(block_count * block.BLOCK_LENGTH),
        .channels = 2,
        .samplerate = 48000,
        .format = sndfile.SF_FORMAT_WAV | sndfile.SF_FORMAT_FLOAT,
    };

    const c_filename = try buf_allocator.dupeZ(u8, filename);
    defer buf_allocator.free(c_filename);

    const f = sndfile.sf_open(c_filename, sndfile.SFM_WRITE, &sfinfo);
    defer _ = sndfile.sf_close(f);

    for (0..block_count) |_| {
        const res = try e.eval(instructions, stack_allocator);
        for (0..block.BLOCK_LENGTH) |i| {
            buf[i * 2] = res.get(0, i);
            buf[i * 2 + 1] = res.get(1, i);
        }

        _ = sndfile.sf_write_float(f, &buf, block.BLOCK_LENGTH);
    }
}
