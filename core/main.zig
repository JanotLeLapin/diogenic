const std = @import("std");
const log = std.log.scoped(.core);

const portaudio = @cImport({
    @cInclude("portaudio.h");
});

const compiler = @import("compiler.zig");
const CompilerState = compiler.CompilerState;

const engine = @import("engine.zig");
const EngineState = engine.EngineState;

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

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

pub fn compile(state: *CompilerState, root: *Node, alloc: std.mem.Allocator) !std.ArrayList(Instruction) {
    var pre_stack = try std.ArrayList(*Node).initCapacity(alloc, 32);
    defer pre_stack.deinit(alloc);

    var post_stack = try std.ArrayList(Instruction).initCapacity(alloc, 32);
    defer post_stack.deinit(alloc);

    try pre_stack.append(alloc, root);

    var has_error = false;
    while (pre_stack.items.len > 0) {
        const tmp = pre_stack.pop().?;
        if (instruction.compile(state, tmp)) |instr| {
            try post_stack.append(alloc, instr);
        } else |err| {
            has_error = true;
            log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
            continue;
        }

        const children = switch (tmp.data) {
            .list => |lst| lst,
            else => continue,
        };

        for (children.items) |child| {
            switch (child.data) {
                .id => continue,
                else => {},
            }

            try pre_stack.append(alloc, child);
        }
    }

    if (has_error) {
        return error.CompilationError;
    }

    var res = try std.ArrayList(Instruction).initCapacity(alloc, 64);
    while (post_stack.pop()) |tmp| {
        try res.append(alloc, tmp);
    }

    return res;
}

pub fn eval(state: *EngineState, instructions: []const Instruction) !void {
    state.stack_head = 0;
    for (instructions) |instr| {
        switch (instr) {
            inline else => |device| device.eval(state),
        }
    }
}

const CallbackData = struct {
    engine_state: *EngineState,
    instructions: []const Instruction,
};

pub fn callback(
    input_buffer: ?*const anyopaque,
    output_buffer: ?*anyopaque,
    frames_per_buffer: c_ulong,
    time_info: ?*const portaudio.PaStreamCallbackTimeInfo,
    status_flags: portaudio.PaStreamCallbackFlags,
    user_data: ?*anyopaque,
) callconv(.c) i32 {
    const data: *CallbackData = @ptrCast(@alignCast(user_data));
    const out: [*]f32 = @ptrCast(@alignCast(output_buffer));
    _ = input_buffer;
    _ = time_info;
    _ = status_flags;

    eval(data.engine_state, data.instructions) catch return 1;
    for (0..frames_per_buffer) |i| {
        out[i * 2] = data.engine_state.stack[0].get(0, i);
        out[i * 2 + 1] = data.engine_state.stack[0].get(1, i);
    }

    return 0;
}

pub fn main() !void {
    const input = "(* 1.5 (+ 2 3))";
    var tokenizer = Tokenizer{ .src = input };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var ast_alloc = std.heap.ArenaAllocator.init(gpa.allocator());
    defer ast_alloc.deinit();

    const root = try parser.parse(&tokenizer, ast_alloc.allocator(), gpa.allocator());

    var e = try EngineState.init(gpa.allocator(), 48000);
    defer e.deinit();

    var cs = CompilerState{};

    var instructions = compile(&cs, root.data.list.items[0], gpa.allocator()) catch {
        log.err("compilation failed", .{});
        return;
    };
    defer instructions.deinit(gpa.allocator());

    for (instructions.items) |instr| {
        switch (instr) {
            .value => |v| log.debug("instr: value: {d}", .{v.value}),
            else => {
                const tag = std.meta.activeTag(instr);
                log.debug("instr: {s}", .{@tagName(tag)});
            },
        }
    }

    switch (portaudio.Pa_Initialize()) {
        portaudio.paNoError => {},
        else => |err| {
            log.err("could not initialize portaudio: {s}", .{portaudio.Pa_GetErrorText(err)});
            return;
        },
    }
    defer _ = portaudio.Pa_Terminate();

    var userdata: CallbackData = .{
        .engine_state = &e,
        .instructions = instructions.items,
    };
    var stream: ?*portaudio.PaStream = undefined;
    switch (portaudio.Pa_OpenDefaultStream(
        &stream,
        0,
        2,
        portaudio.paFloat32,
        @floatCast(e.sr),
        engine.BLOCK_LENGTH,
        &callback,
        @ptrCast(&userdata),
    )) {
        portaudio.paNoError => {},
        else => |err| {
            log.err("could not open portaudio stream: {s}", .{portaudio.Pa_GetErrorText(err)});
            return;
        },
    }

    switch (portaudio.Pa_StartStream(stream)) {
        portaudio.paNoError => {},
        else => |err| {
            log.err("could not start portaudio stream: {s}", .{portaudio.Pa_GetErrorText(err)});
        },
    }
    defer _ = portaudio.Pa_StopStream(stream);

    portaudio.Pa_Sleep(5000);
}
