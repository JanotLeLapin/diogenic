const builtin = @import("builtin");
const std = @import("std");

const log = std.log.scoped(.repl);

const core = @import("diogenic-core");
const compiler = core.compiler;

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

    s.buf.clearRetainingCapacity();
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

    return s.buf.items[1..];
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

    while (true) {
        log.info("input => ", .{});
        const res = try readLoop(&state);

        if (std.mem.eql(u8, ":q", res)) {
            break;
        }
    }
}
