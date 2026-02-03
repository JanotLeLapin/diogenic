const std = @import("std");
const log = std.log.scoped(.core);

const rl = @import("raylib");

const repl = @import("repl.zig");
const render = @import("render.zig");

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

const RenderOptions = struct {
    path: []const u8,
    sample_rate: f32 = 44100.0,
    seconds: f32 = 30.0,

    pub fn parse(gpa: std.mem.Allocator, args: []const [:0]const u8) !RenderOptions {
        const src = try gpa.alloc(u8, args[0].len);
        @memcpy(src, args[0]);
        var self: RenderOptions = .{ .path = src };

        var i: usize = 1;
        while (i < args.len) : (i += 2) {
            if (std.mem.eql(u8, "--sample-rate", args[i])) {
                self.sample_rate = try std.fmt.parseFloat(f32, args[i + 1]);
            } else if (std.mem.eql(u8, "--seconds", args[i])) {
                self.seconds = try std.fmt.parseFloat(f32, args[i + 1]);
            }
        }

        return self;
    }
};

const Command = union(enum) {
    help: void,
    repl: void,
    render: RenderOptions,
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

        if (std.mem.eql(u8, "help", args[1])) {
            break :blk Command{ .help = {} };
        }
        if (std.mem.eql(u8, "repl", args[1])) {
            break :blk Command{ .repl = {} };
        }
        if (std.mem.eql(u8, "render", args[1])) {
            const opts = RenderOptions.parse(gpa.allocator(), args[2..]) catch {
                log.err("could not parse options", .{});
                return;
            };
            break :blk Command{ .render = opts };
        } else {
            log.err("unknown command", .{});
            return;
        }
    };

    switch (args) {
        .help => {
            var stdout_buf: [1024]u8 = undefined;
            var stdout = std.fs.File.stdout().writer(&stdout_buf);

            _ = try stdout.interface.write("diogenic\n\n");
            _ = try stdout.interface.write(" help      display this message\n");
            _ = try stdout.interface.write(" repl      start an interactive repl\n");
            _ = try stdout.interface.write(" render    generate an audio file from a diogenic file\n");
            try stdout.interface.flush();
        },
        .repl => try repl.repl(gpa.allocator()),
        .render => |opts| {
            try render.render(
                gpa.allocator(),
                opts.path,
                opts.sample_rate,
                opts.seconds,
            );
            gpa.allocator().free(opts.path);
        },
    }
}
