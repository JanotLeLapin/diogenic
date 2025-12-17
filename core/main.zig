const std = @import("std");
const log = std.log.scoped(.core);

const compiler = @import("compiler.zig");

const engine = @import("engine.zig");
const EngineState = engine.EngineState;

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Tokenizer = parser.Tokenizer;

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
    _ = root;

    var e = try EngineState.init(gpa.allocator());
    defer e.deinit();
}
