const std = @import("std");
const log = std.log.scoped(.core);

pub const compiler = @import("compiler.zig");

pub const engine = @import("engine.zig");
const EngineState = engine.EngineState;

pub const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

pub const parser = @import("parser.zig");

pub const Colors = @import("colors.zig");

pub fn initState(sr: f32, instructions: []const Instruction, alloc: std.mem.Allocator) !EngineState {
    var stack_size: usize = 0;
    var state_size: usize = 0;
    var reg_size: usize = 0;

    for (instructions) |instr| {
        switch (instr) {
            ._pop, ._free => {},
            ._push => {
                stack_size += 1;
            },
            ._store => {
                reg_size += 1;
            },
            ._load => {
                stack_size += 1;
            },
            inline else => |device| {
                const T = @TypeOf(device);
                stack_size += 1;
                state_size += if (@hasDecl(T, "state_count")) T.state_count else 0;
                reg_size += if (@hasDecl(T, "register_count")) T.register_count else 0;
            },
        }
    }

    return EngineState.init(sr, stack_size, state_size, reg_size, alloc);
}

pub fn compileExpr(state: *compiler.types.State, node: *parser.Node) !void {
    try compiler.alpha.expand(state, node);
    try compiler.fold.expand(state, node);
    try compiler.rpn.expand(state, node);
}

pub fn printExceptions(
    state: *compiler.types.State,
    root_mod: *compiler.types.Module,
    exceptions: []compiler.types.Exception,
) !void {
    var stderr_buffer: [4096]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&stderr_buffer);

    for (exceptions) |ex| {
        try compiler.exception.printExceptionContext(
            (state.map.get(ex.node.src_file) orelse root_mod).sourcemap,
            ex,
            &stderr.interface,
        );
        try stderr.interface.flush();
    }
}

pub fn eval(state: *EngineState, instructions: []const Instruction) !void {
    var stack_head: usize = 0;
    var state_head: usize = 0;
    var reg_head: usize = 0;
    for (instructions) |instr| {
        switch (instr) {
            ._push => |push| {
                var b = &state.stack[stack_head];
                for (&b.channels) |*chan| {
                    for (chan) |*vec| {
                        vec.* = @splat(push.value);
                    }
                }
                stack_head += 1;
            },
            ._pop => {
                stack_head -= 1;
            },
            ._store => |store| {
                stack_head -= 1;
                state.reg[store.reg_index] = state.stack[stack_head];
            },
            ._load => |load| {
                state.stack[stack_head] = state.reg[load.reg_index];
                stack_head += 1;
            },
            ._free => |free| {
                _ = free;
                // TODO: free
            },
            inline else => |device| {
                const T = @TypeOf(device);
                const state_count = if (@hasDecl(T, "state_count")) T.state_count else 0;
                const reg_count = if (@hasDecl(T, "register_count")) T.register_count else 0;

                const in_start = stack_head - T.args.len;
                const out_end = in_start + 1;

                const inputs = state.stack[in_start..stack_head];
                const output = &state.stack[in_start];

                const eval_data: engine.EvalData = .{
                    .sample_rate = state.sr,
                    .inputs = inputs,
                    .output = output,
                    .state = state.state[state_head .. state_head + state_count],
                    .registry = state.reg[reg_head .. reg_head + reg_count],
                };

                device.eval(eval_data);

                stack_head = out_end;
                state_head += state_count;
                reg_head += reg_count;
            },
        }
    }
}
