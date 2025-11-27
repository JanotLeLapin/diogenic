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

    var parser_arena = std.heap.ArenaAllocator.init(gpa);
    defer parser_arena.deinit();

    var compiler_arena = std.heap.ArenaAllocator.init(gpa);
    defer compiler_arena.deinit();

    const parser_alloc = parser.ParserAlloc{
        .ast_alloc = parser_arena.allocator(),
        .temp_stack_allocator = gpa,
    };

    const compiler_alloc = compiler.CompilerAlloc{
        .instr_alloc = compiler_arena.allocator(),
        .temp_stack_alloc = gpa,
    };

    const instr = instr: {
        var timer = try std.time.Timer.start();
        const instr = try root.compileSource(src, parser_alloc, compiler_alloc);
        const time: f32 = @floatFromInt(timer.read() / 1_000); // microseconds
        std.log.info("Compiled source, took {d:.3}ms", .{time / 1_000});
        break :instr instr;
    };

    // std.debug.print("rpn:\n", .{});
    // for (instr.items) |item| {
    //     std.debug.print("{f}\n", .{item});
    // }

    const sec_count = 60;
    const sample_count = sec_count * 48000;
    const block_count = sample_count / block.BLOCK_LENGTH;
    var e = try engine.Engine.init(gpa);
    {
        var timer = try std.time.Timer.start();
        try renderWav32("out.wav", instr.items, &e, block_count, gpa);
        const time: f32 = @floatFromInt(timer.read() / 1_000); // microseconds
        std.log.info("Rendered {d} blocks, took {d:.3}ms ({d:.3}ms per block, {d:.5}ms per sample)", .{
            block_count,
            time / 1_000,
            (time / 1_000) / block_count,
            (time / 1_000) / (block_count * block.BLOCK_LENGTH),
        });
    }
}
