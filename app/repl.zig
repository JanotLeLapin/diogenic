const builtin = @import("builtin");
const std = @import("std");

const log = std.log.scoped(.repl);

const core = @import("diogenic-core");
const compiler = core.compiler;
const CompilerState = compiler.types.State;
const FunctionMap = compiler.types.FunctionMap;

const audio = @import("audio.zig");

pub const State = struct {
    buf: std.ArrayList(u8),
    buf_alloc: std.mem.Allocator,
    modmap: compiler.types.ModuleMap,
};

fn readLine(line_buf: []u8, input: *std.Io.Reader) ![]const u8 {
    var w = std.io.Writer.fixed(line_buf);

    var len = try input.streamDelimiterLimit(&w, '\n', .unlimited);
    std.debug.assert(len <= line_buf.len);

    var b: ?u8 = null;
    if (input.takeByte()) |v| {
        b = v;
    } else |err| switch (err) {
        error.EndOfStream => {
            std.debug.assert(b == null);
        },
        else => return err,
    }
    std.debug.assert(b == '\n' or b == null);

    if (builtin.os.tag == .windows) {
        if (len > 0 and b == '\n' and line_buf[len - 1] == '\r') {
            len -= 1;
        }
    }

    return line_buf[0..len];
}

fn readLoop(s: *State) ![]const u8 {
    var str = false;
    var c: isize = 0;

    var line_buf: [1024]u8 = undefined;
    var stdin_buf: [1024]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&stdin_buf);

    const start = s.buf.items.len;
    while (true) {
        const res = try readLine(line_buf[0..], &stdin.interface);
        for (res) |ch| {
            switch (ch) {
                '"' => str = !str,
                else => {},
            }

            if (str) {
                continue;
            }

            switch (ch) {
                '(' => c += 1,
                ')' => c -= 1,
                else => {},
            }
        }
        try s.buf.append(s.buf_alloc, '\n');
        try s.buf.appendSlice(s.buf_alloc, res);

        if (0 >= c) {
            break;
        }
    }

    return s.buf.items[(start + 1)..];
}

pub fn repl(gpa: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var buf = try std.ArrayList(u8).initCapacity(gpa, 1024);
    defer buf.deinit(gpa);

    var state: State = .{
        .buf = buf,
        .buf_alloc = gpa,
        .modmap = core.compiler.types.ModuleMap.init(arena.allocator()),
    };

    var mod_map = core.compiler.types.ModuleMap.init(arena.allocator());
    defer mod_map.deinit();

    var instr_seq = try std.ArrayList(core.instruction.Instruction).initCapacity(gpa, 8);
    defer instr_seq.deinit(gpa);

    var exceptions = try std.ArrayList(core.compiler.types.Exception).initCapacity(gpa, 8);
    defer exceptions.deinit(gpa);

    var env = std.StringHashMap(usize).init(gpa);
    defer env.deinit();

    var cs: CompilerState = .{
        .map = &mod_map,
        .instr_seq = &instr_seq,
        .exceptions = &exceptions,
        .env = &env,
        .arena_alloc = arena.allocator(),
        .stack_alloc = gpa,
    };

    var fn_map = FunctionMap.init(arena.allocator());

    try audio.init();
    defer audio.deinit() catch {};

    var e: ?core.engine.EngineState = null;
    var audio_stream_data: ?audio.CallbackData = null;
    var audio_stream: ?*anyopaque = null;

    while (true) {
        exceptions.clearRetainingCapacity();

        log.info("input =>", .{});
        const res = try readLoop(&state);

        if (std.mem.eql(u8, ":q", res)) {
            break;
        } else if (std.mem.eql(u8, ":p", res)) {
            if (audio_stream) |stream| {
                try audio.stopStream(stream);
                audio_stream = null;
                continue;
            }

            e = try core.initState(44100.0, instr_seq.items, gpa);
            audio_stream_data = .{
                .engine_state = &e.?,
                .instructions = instr_seq.items,
            };

            audio_stream = try audio.openStream(e.?.sr, &audio_stream_data.?);

            try audio.startStream(audio_stream);

            continue;
        }

        const mod = try compiler.module.resolveImports(&cs, "main", res);
        if (0 == mod.root.data.list.items.len) {
            continue;
        }

        var fn_iter = mod.functions.iterator();
        while (fn_iter.next()) |entry| {
            try fn_map.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        for (mod.imports.items) |import| {
            fn_iter = import.functions.iterator();
            while (fn_iter.next()) |entry| {
                try fn_map.put(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        mod.functions = fn_map;

        try compiler.function.expand(&cs, mod);

        const node = mod.root.data.list.getLast();
        const op = switch (node.data.list.items[0].data) {
            .id => |id| id,
            else => continue,
        };

        if (std.mem.eql(u8, "defun", op) or std.mem.eql(u8, "use", op)) {
            continue;
        }

        instr_seq.clearRetainingCapacity();
        try compiler.alpha.expand(&cs, node);
        try compiler.rpn.expand(&cs, node);

        if (0 < exceptions.items.len) {
            var stderr_buffer: [4096]u8 = undefined;
            var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
            const stderr: *std.Io.Writer = &stderr_writer.interface;
            for (exceptions.items) |ex| {
                try core.compiler.exception.printExceptionContext(
                    mod.sourcemap,
                    ex,
                    stderr,
                );
                try stderr.flush();
            }
            continue;
        }

        log.info("compiled {d} instructions", .{instr_seq.items.len});
    }

    if (audio_stream) |stream| {
        try audio.stopStream(stream);
    }
}
