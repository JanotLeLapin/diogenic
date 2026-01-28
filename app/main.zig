const std = @import("std");
const log = std.log.scoped(.core);

const rl = @import("raylib");

const audio = @import("audio.zig");

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

const Args = struct {
    src: []const u8,
    action: enum {
        render,
        display,
        playback,
        inspect,
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const args = src: {
        const args = try std.process.argsAlloc(gpa.allocator());
        defer std.process.argsFree(gpa.allocator(), args);

        if (args.len < 3) {
            log.err("bad usage, expected: diogenic <source> <render|display|playback>\n", .{});
            return;
        }

        const file = try std.fs.cwd().openFile(args[1], .{});
        defer file.close();

        break :src Args{
            .src = try file.readToEndAlloc(gpa.allocator(), 10 * 1024 * 1024),
            .action = if (std.mem.eql(u8, "render", args[2]))
                .render
            else if (std.mem.eql(u8, "display", args[2]))
                .display
            else if (std.mem.eql(u8, "play", args[2]))
                .playback
            else if (std.mem.eql(u8, "inspect", args[2]))
                .inspect
            else {
                log.err("bad usage, expected: diogenic <source> <render|display|playback>\n", .{});
                return;
            },
        };
    };
    defer gpa.allocator().free(args.src);

    var ast_alloc = std.heap.ArenaAllocator.init(gpa.allocator());
    defer ast_alloc.deinit();

    var mod_map = core.compiler.types.ModuleMap.init(ast_alloc.allocator());
    defer mod_map.deinit();

    var instr_seq = try std.ArrayList(core.instruction.Instruction).initCapacity(gpa.allocator(), 8);
    defer instr_seq.deinit(gpa.allocator());

    var exceptions = try std.ArrayList(core.compiler.types.Exception).initCapacity(gpa.allocator(), 8);
    defer exceptions.deinit(gpa.allocator());

    var env = std.StringHashMap(usize).init(gpa.allocator());
    defer env.deinit();

    var state = core.compiler.types.State{
        .map = &mod_map,
        .instr_seq = &instr_seq,
        .exceptions = &exceptions,
        .env = &env,
        .arena_alloc = ast_alloc.allocator(),
        .stack_alloc = gpa.allocator(),
    };
    const mod = try core.compiler.module.resolveImports(&state, "main", args.src);
    try core.compiler.function.expand(&state, mod);
    try core.compiler.alpha.expand(&state, mod.root.data.list.getLast());
    try core.compiler.rpn.expand(&state, mod.root.data.list.getLast());

    var e = try core.initState(44100.0, instr_seq.items, gpa.allocator());
    defer e.deinit();

    if (0 < state.exceptions.items.len) {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        const stderr: *std.Io.Writer = &stderr_writer.interface;
        for (state.exceptions.items) |ex| {
            try core.compiler.exception.printExceptionContext(mod.sourcemap, ex, stderr);
            try stderr.flush();
        }
        return;
    }

    for (instr_seq.items) |instr| {
        switch (instr) {
            ._push => |v| log.debug("instr: value: {d}", .{v.value}),
            ._store => |v| log.debug("instr: store: idx = {d}", .{v.reg_index}),
            ._load => |v| log.debug("instr: load: idx = {d}", .{v.reg_index}),
            ._free => |v| log.debug("instr: free: idx = {d}", .{v.reg_index}),
            else => {
                const tag = std.meta.activeTag(instr);
                log.debug("instr: {s}", .{@tagName(tag)});
            },
        }
    }

    switch (args.action) {
        .display => {
            const screenWidth = 850;
            const screenHeight = 800;
            const fps = 60.0;
            const samplesPerFrame = e.sr / fps;
            const blocksPerFrame = samplesPerFrame / @as(f32, @floatFromInt(core.engine.BLOCK_LENGTH));
            rl.initWindow(screenWidth, screenHeight, "diogenic");
            defer rl.closeWindow();

            rl.setTargetFPS(@intFromFloat(fps));

            var prev_y: [2]i32 = undefined;
            prev_y[0] = 0;
            prev_y[1] = 0;
            while (!rl.windowShouldClose()) {
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(.black);
                var x: i32 = 0;
                for (0..@as(usize, @intFromFloat(@ceil(blocksPerFrame)))) |_| {
                    core.eval(&e, instr_seq.items) catch {};

                    for (0..core.engine.BLOCK_LENGTH) |j| {
                        for (0..2) |k| {
                            const amp = e.stack[0].get(@intCast(k), j);
                            var y = @min(@max(amp, -1.0), 1.0);
                            y = @floor((y * 0.5 + 0.5) * @as(f32, @floatFromInt(screenHeight)));
                            y = y / 4 + @as(f32, @floatFromInt(k)) * (@as(f32, @floatFromInt(screenHeight)) / 4);

                            rl.drawLine(@max(x - 1, 0), prev_y[k], x, @intFromFloat(y), .white);
                            prev_y[k] = @intFromFloat(y);
                        }
                        x += 1;
                    }
                }
            }
        },
        .render => {
            const block_count: usize = @intFromFloat(e.sr / @as(f32, @floatFromInt(core.engine.BLOCK_LENGTH)) * 300);
            var timer = try std.time.Timer.start();
            try audio.renderWav32(
                "out.wav",
                &e,
                instr_seq.items,
                block_count,
                gpa.allocator(),
            );
            const time: f32 = @floatFromInt(timer.read() / 1_000);
            const ms_time = time / 1_000;
            const time_per_sample = ms_time / @as(f32, @floatFromInt(block_count * core.engine.BLOCK_LENGTH));
            const time_per_second = time_per_sample * e.sr;
            const headroom = 1_000 - time_per_second;
            log.info("rendered {} blocks, took {d:.3}ms ({d:.5}ms/sample, {d:.5}ms/second, {d:.5}ms headroom)", .{
                block_count,
                ms_time,
                time_per_sample,
                time_per_second,
                headroom,
            });
        },
        .playback => {
            try audio.init();
            defer _ = audio.deinit() catch {};
            var userdata: audio.CallbackData = .{
                .engine_state = &e,
                .instructions = instr_seq.items,
            };

            const stream = try audio.openStream(e.sr, &userdata);
            try audio.startStream(stream);
            defer _ = audio.stopStream(stream) catch {};

            audio.sleep(15000);
        },
        .inspect => {},
    }
}
