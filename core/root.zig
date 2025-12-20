const std = @import("std");
const log = std.log.scoped(.core);

pub const compiler = @import("compiler.zig");

pub const engine = @import("engine.zig");
const EngineState = engine.EngineState;

pub const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

pub const parser = @import("parser.zig");

pub fn eval(state: *EngineState, instructions: []const Instruction) !void {
    var stack_head: usize = 0;
    for (instructions) |instr| {
        switch (instr) {
            inline else => |device| {
                const T = @TypeOf(device);
                const in_start = stack_head - T.input_count;
                const out_end = in_start + T.output_count;

                const inputs = state.stack[in_start..stack_head];
                const outputs = state.stack[in_start..out_end];

                device.eval(inputs, outputs, state);

                stack_head = out_end;
            },
        }
    }
}
