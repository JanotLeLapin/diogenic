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
    var state_head: usize = 0;
    var reg_head: usize = 0;
    for (instructions) |instr| {
        switch (instr) {
            .push => |push| {
                var b = &state.stack[stack_head];
                for (&b.channels) |*chan| {
                    for (chan) |*vec| {
                        vec.* = @splat(push.value);
                    }
                }
                stack_head += 1;
            },
            .pop => {
                stack_head -= 1;
            },
            .store => |store| {
                stack_head -= 1;
                state.reg[store.reg_index] = state.stack[stack_head];
            },
            .load => |load| {
                state.stack[stack_head] = state.reg[load.reg_index];
                stack_head += 1;
            },
            .free => |free| {
                _ = free;
                // TODO: free
            },
            inline else => |device| {
                const T = @TypeOf(device);
                const state_count = if (@hasDecl(T, "state_count")) T.state_count else 0;
                const reg_count = if (@hasDecl(T, "register_count")) T.register_count else 0;

                const in_start = stack_head - T.input_count;
                const out_end = in_start + T.output_count;

                const inputs = state.stack[in_start..stack_head];
                const outputs = state.stack[in_start..out_end];

                device.eval(
                    inputs,
                    outputs,
                    state.state[state_head .. state_head + state_count],
                    state.reg[reg_head .. reg_head + reg_count],
                );

                stack_head = out_end;
                state_head += state_count;
                reg_head += reg_count;
            },
        }
    }
}
