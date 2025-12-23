const std = @import("std");
const log = std.log.scoped(.core);

const rl = @import("raylib");

const audio = @import("audio.zig");

const core = @import("diogenic-core");
const CompilerState = core.engine.CompilerState;
const EngineState = core.engine.EngineState;
const Instruction = core.instruction.Instruction;
const Tokenizer = core.parser.Tokenizer;

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const src = src: {
        const args = try std.process.argsAlloc(gpa.allocator());
        defer std.process.argsFree(gpa.allocator(), args);

        if (args.len < 2) {
            log.err("missing input file\n", .{});
            return;
        }

        const file = try std.fs.cwd().openFile(args[1], .{});
        defer file.close();

        break :src try file.readToEndAlloc(gpa.allocator(), 10 * 1024 * 1024);
    };
    defer gpa.allocator().free(src);

    var tokenizer = Tokenizer{ .src = src };

    var ast_alloc = std.heap.ArenaAllocator.init(gpa.allocator());
    defer ast_alloc.deinit();

    const root = try core.parser.parse(&tokenizer, ast_alloc.allocator(), gpa.allocator());

    var cs = CompilerState{ .env = std.StringHashMap(usize).init(gpa.allocator()) };
    defer cs.env.deinit();

    var instructions = try std.ArrayList(Instruction).initCapacity(gpa.allocator(), 64);
    defer instructions.deinit(gpa.allocator());

    core.compiler.compile(
        &cs,
        root.data.list.items[0],
        &instructions,
        gpa.allocator(),
        ast_alloc.allocator(),
    ) catch {
        log.err("compilation failed", .{});
        return;
    };

    var e = try core.initState(48000, instructions.items, gpa.allocator());
    defer e.deinit();

    for (instructions.items) |instr| {
        switch (instr) {
            .push => |v| log.debug("instr: value: {d}", .{v.value}),
            else => {
                const tag = std.meta.activeTag(instr);
                log.debug("instr: {s}", .{@tagName(tag)});
            },
        }
    }

    // try audio.init();
    // defer _ = audio.deinit() catch {};
    // var userdata: audio.CallbackData = .{
    //     .engine_state = &e,
    //     .instructions = instructions.items,
    // };

    // const stream = try audio.openStream(e.sr, &userdata);
    // try audio.startStream(stream);
    // defer _ = audio.stopStream(stream) catch {};

    const screenWidth = 625;
    const screenHeight = 450;
    const fps = 60.0;
    const samplesPerFrame = e.sr / fps;
    const blocksPerFrame = samplesPerFrame / @as(f32, @floatFromInt(core.engine.BLOCK_LENGTH));
    rl.initWindow(screenWidth, screenHeight, "diogenic");
    defer rl.closeWindow();

    rl.setTargetFPS(@intFromFloat(fps));

    var prev_y: i32 = 0;
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);
        var x: i32 = 0;
        for (0..@as(usize, @intFromFloat(@ceil(blocksPerFrame)))) |_| {
            core.eval(&e, instructions.items) catch {};

            for (0..core.engine.BLOCK_LENGTH) |j| {
                const amp = e.stack[0].get(0, j);
                const y: i32 = @intFromFloat(@floor((amp * 0.5 + 0.5) * @as(f32, @floatFromInt(screenHeight))));

                rl.drawLine(@max(x - 1, 0), prev_y, x, y, .black);
                x += 1;
                prev_y = y;
            }
        }
    }
}
