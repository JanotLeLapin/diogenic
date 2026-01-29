const std = @import("std");
const log = std.log.scoped(.core);

const rl = @import("raylib");

const audio = @import("audio.zig");
const repl = @import("repl.zig");

const core = @import("diogenic-core");
const EngineState = core.engine.EngineState;

const sourcemap = core.compiler.sourcemap;
const SourceMap = sourcemap.SourceMap;

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderrWriter(&buffer);
    const ttyconf = std.Io.tty.Config.detect(std.fs.File.stderr());
    defer std.debug.unlockStderrWriter();
    ttyconf.setColor(stderr, switch (message_level) {
        .err => .red,
        .warn => .yellow,
        .info => .green,
        .debug => .magenta,
    }) catch {};
    ttyconf.setColor(stderr, .bold) catch {};
    stderr.writeAll(message_level.asText()) catch return;
    ttyconf.setColor(stderr, .reset) catch {};
    ttyconf.setColor(stderr, .dim) catch {};
    ttyconf.setColor(stderr, .bold) catch {};
    if (scope != .default) {
        stderr.print("({s})", .{@tagName(scope)}) catch return;
    }
    stderr.writeAll(": ") catch return;
    ttyconf.setColor(stderr, .reset) catch {};
    stderr.print(format ++ "\n", args) catch return;
}

pub const std_options = std.Options{
    .logFn = logFn,
};

const Command = union(enum) {
    repl: void,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const args = blk: {
        const args = try std.process.argsAlloc(gpa.allocator());
        defer std.process.argsFree(gpa.allocator(), args);

        if (2 > args.len) {
            log.err("not enough arguments", .{});
            return;
        }

        if (std.mem.eql(u8, "repl", args[1])) {
            break :blk Command{ .repl = {} };
        } else {
            log.err("unknown command", .{});
            return;
        }
    };

    switch (args) {
        .repl => try repl.repl(gpa.allocator()),
    }
}
