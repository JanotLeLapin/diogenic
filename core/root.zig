const std = @import("std");
const log = std.log.scoped(.core);

pub const compiler = @import("compiler.zig");

pub const engine = @import("engine.zig");
const EngineState = engine.EngineState;

pub const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

pub const parser = @import("parser.zig");

pub fn eval(state: *EngineState, instructions: []const Instruction) !void {
    state.stack_head = 0;
    for (instructions) |instr| {
        switch (instr) {
            inline else => |device| device.eval(state),
        }
    }
}
