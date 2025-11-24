const std = @import("std");

const root = @import("root.zig");

const ast = @import("ast.zig");
const instruction = @import("instruction.zig");
const parser = @import("parser.zig");
const compiler = @import("compiler.zig");

const engine = @import("dsp/engine.zig");
const block = @import("dsp/block.zig");

const sndfile = @cImport({
    @cInclude("sndfile.h");
});

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
        try root.renderBlock(instructions, e, &buf, 0);
        _ = sndfile.sf_write_float(f, &buf, block.BLOCK_LENGTH * 2);
    }
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const src = src: {
        const args = try std.process.argsAlloc(gpa);
        defer std.process.argsFree(gpa, args);

        if (args.len < 2) {
            std.log.err("missing input file\n", .{});
            return;
        }

        const file = try std.fs.cwd().openFile(args[1], .{});
        break :src try file.readToEndAlloc(gpa, 10 * 1024 * 1024);
    };

    var ast_arena = std.heap.ArenaAllocator.init(gpa);
    defer ast_arena.deinit();
    const ast_arena_alloc = ast_arena.allocator();

    var instr_arena = std.heap.ArenaAllocator.init(gpa);
    defer instr_arena.deinit();
    const instr_arena_alloc = instr_arena.allocator();

    const instr = try root.compileSource(src, ast_arena_alloc, gpa, instr_arena_alloc, gpa);

    // std.debug.print("rpn:\n", .{});
    // for (instr.items) |item| {
    //     std.debug.print("{f}\n", .{item});
    // }

    const block_count = 22500;
    var e = try engine.Engine.init(gpa);
    var timer = try std.time.Timer.start();
    try renderWav32("out.wav", instr.items, &e, block_count, gpa);
    const time = timer.read();
    std.log.info("Rendered {d} blocks ({d} samples), took {d}ms", .{ block_count, block_count * block.BLOCK_LENGTH, time / 1_000_000 });
}
