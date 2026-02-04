const builtin = @import("builtin");
const std = @import("std");

const core = @import("diogenic-core");
const compiler = core.compiler;
const CompilerState = compiler.types.State;
const FunctionMap = compiler.types.FunctionMap;

const audio = @import("audio.zig");

const Colors = core.Colors;

pub const State = struct {
    running: bool,
    stdout: *std.Io.Writer,
    gpa: std.mem.Allocator,
    buf: std.ArrayList(u8),
    buf_alloc: std.mem.Allocator,
    fn_map: *FunctionMap,
    instr_seq: *std.ArrayList(core.instruction.Instruction),
    engine: ?core.engine.EngineState,
    stream: ?*anyopaque,
    stream_data: ?audio.CallbackData,
};

const CommandHook = *const fn (*State, args: []const u8) anyerror!void;

const CommandMap = std.StaticStringMap(CommandHook).initComptime(.{
    .{ ":q", quitCmd },
    .{ ":p", playCmd },
    .{ ":h", helpCmd },
});

fn quitCmd(s: *State, _: []const u8) !void {
    s.running = false;
}

fn playCmd(s: *State, _: []const u8) !void {
    if (0 == s.instr_seq.items.len) {
        _ = try Colors.setRed(s.stdout);
        _ = try s.stdout.write("instruction sequence is empty\n");
        _ = try Colors.setReset(s.stdout);
        return;
    }

    if (s.stream) |stream| {
        _ = try s.stdout.write("pausing playback\n");
        try audio.stopStream(stream);
        s.stream = null;
        return;
    }

    if (s.engine) |*engine| {
        engine.deinit();
    }

    _ = try s.stdout.write("starting playback\n");
    s.engine = try core.initState(44100.0, s.instr_seq.items, s.gpa);
    s.stream_data = .{
        .engine_state = &s.engine.?,
        .instructions = s.instr_seq.items,
    };

    s.stream = try audio.openStream(s.engine.?.sr, &s.stream_data.?);

    try audio.startStream(s.stream);
}

fn helpCmd(s: *State, args: []const u8) !void {
    if (0 == args.len) {
        _ = try s.stdout.write("\n");
        _ = try s.stdout.write(" :p        plays the latest compiled expression\n");
        _ = try s.stdout.write(" :h [fn]   displays this message, or help for the given function\n");
        _ = try s.stdout.write(" :q        quits\n");
        _ = try s.stdout.write("\n");
        return;
    }

    const f = s.fn_map.get(args) orelse {
        try s.stdout.print("command '{s}' not found.\n", .{args});
        return;
    };

    _ = try s.stdout.write("\n");
    _ = try Colors.setMagenta(s.stdout);
    _ = try s.stdout.write(args);
    _ = try Colors.setReset(s.stdout);
    try s.stdout.print(": {s}\n", .{f.doc orelse "/"});

    for (f.args.items) |arg_key| {
        const arg = f.arg_map.get(arg_key) orelse continue;
        _ = try s.stdout.write("- ");
        _ = try Colors.setMagenta(s.stdout);
        _ = try s.stdout.write(arg_key);
        _ = try Colors.setReset(s.stdout);
        try s.stdout.print(": {s}\n", .{arg.doc orelse "/"});
    }

    _ = try s.stdout.write("\n");
}

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
    var stdout_buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buf);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var instr_arena = std.heap.ArenaAllocator.init(gpa);
    defer instr_arena.deinit();

    var fn_map = FunctionMap.init(arena.allocator());

    var src_arena = std.heap.ArenaAllocator.init(gpa);
    defer src_arena.deinit();

    const buf = try std.ArrayList(u8).initCapacity(src_arena.allocator(), 1024);

    var instr_seq = try std.ArrayList(core.instruction.Instruction).initCapacity(gpa, 8);
    defer instr_seq.deinit(gpa);

    var state: State = .{
        .running = true,
        .stdout = &stdout.interface,
        .gpa = gpa,
        .buf = buf,
        .buf_alloc = gpa,
        .fn_map = &fn_map,
        .instr_seq = &instr_seq,
        .engine = null,
        .stream = null,
        .stream_data = null,
    };

    var mod_map = core.compiler.types.ModuleMap.init(arena.allocator());
    defer mod_map.deinit();

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
        .instr_alloc = instr_arena.allocator(),
    };

    try audio.init();
    defer audio.deinit() catch {};

    _ = try stdout.interface.write("diogenic\ntype ':h' for help\n");

    while (state.running) {
        exceptions.clearRetainingCapacity();

        _ = try stdout.interface.write("input => ");
        try stdout.interface.flush();

        const res = try readLoop(&state);

        const space_idx = blk: {
            var i: usize = 0;
            while (i < res.len) : (i += 1) {
                if (res[i] == ' ') {
                    break;
                }
            }

            break :blk i;
        };

        const cmd = res[0..space_idx];
        const args = res[@min(space_idx + 1, res.len)..];

        if (CommandMap.get(cmd)) |hook| {
            try hook(&state, args);
            continue;
        }

        const mod = try compiler.module.resolveImports(&cs, "<input>", res);
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
        try core.compileExpr(&cs, node);

        if (0 < exceptions.items.len) {
            try core.printExceptions(&cs, mod, exceptions.items);
            _ = try Colors.setRed(&stdout.interface);
            _ = try stdout.interface.write("compilation failed\n");
            _ = try Colors.setReset(&stdout.interface);
            continue;
        }

        _ = try Colors.setGreen(&stdout.interface);
        _ = try stdout.interface.print("compiled {d} instructions\n", .{instr_seq.items.len});
        _ = try Colors.setReset(&stdout.interface);
    }

    if (state.stream) |stream| {
        try audio.stopStream(stream);
    }

    if (state.engine) |*engine| {
        engine.deinit();
    }
}
