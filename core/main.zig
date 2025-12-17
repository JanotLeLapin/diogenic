const std = @import("std");
const log = std.log.scoped(.core);

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
    for (instructions) |instr| {
        switch (instr) {
            inline else => |device| device.eval(state),
        }
    }
}

pub fn main() !void {
    const input = "(* 1.5 (+ 2 3))";
    var tokenizer = Tokenizer{ .src = input };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var ast_alloc = std.heap.ArenaAllocator.init(gpa.allocator());
    defer ast_alloc.deinit();

    const root = try parser.parse(&tokenizer, ast_alloc.allocator(), gpa.allocator());

    var e = try EngineState.init(gpa.allocator());
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

    try eval(&e, instructions.items);
    log.debug("= {d}", .{e.stack[0].get(0, 0)});
}
