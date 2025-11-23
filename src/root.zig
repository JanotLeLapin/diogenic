const std = @import("std");

const ast = @import("ast.zig");
const instruction = @import("instruction.zig");

const block = @import("dsp/block.zig");
const engine = @import("dsp/engine.zig");

const sndfile = @cImport({
    @cInclude("sndfile.h");
});

pub fn renderBlock(
    instructions: []instruction.Instruction,
    e: *engine.Engine,
    out: []f32,
    out_offset: usize,
) !void {
    const res = try e.eval(instructions);
    for (0..block.BLOCK_LENGTH) |i| {
        out[out_offset + i * 2] = res.get(0, i);
        out[out_offset + i * 2 + 1] = res.get(1, i);
    }
}

pub fn renderWav32(
    filename: []const u8,
    instructions: []instruction.Instruction,
    e: *engine.Engine,
    block_count: usize,
    buf_allocator: std.mem.Allocator,
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
        try renderBlock(instructions, e, &buf, 0);
        _ = sndfile.sf_write_float(f, &buf, block.BLOCK_LENGTH * 2);
    }
}

pub fn walk_ast(node: *ast.Node, depth: usize) !void {
    switch (node.data) {
        .Expr => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("expr: {s}\n", .{node.data.Expr.op});
            for (node.data.Expr.children.items) |child| {
                try walk_ast(child, depth + 1);
            }
        },
        .Ident => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("id: {s}\n", .{node.data.Ident});
            return;
        },
        .Atom => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("at: {s}\n", .{node.data.Atom});
            return;
        },
        .Value => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("vl: {d}\n", .{node.data.Value});
            return;
        },
    }
}
