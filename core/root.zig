const std = @import("std");
const log = std.log.scoped(.core);

pub const compiler = @import("compiler.zig");
const CompilerState = compiler.CompilerState;

pub const engine = @import("engine.zig");
const EngineState = engine.EngineState;

pub const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

pub const parser = @import("parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub fn compile(state: *CompilerState, tmp: *Node, instructions: *std.ArrayList(Instruction), alloc: std.mem.Allocator) !void {
    const op = switch (tmp.data) {
        .list => |lst| lst.items[0].data.id,
        .num => |num| {
            try instructions.append(
                alloc,
                Instruction{ .value = instruction.value.Push{ .value = num } },
            );
            return;
        },
        .id => |id| {
            if (state.env.get(id)) |idx| {
                try instructions.append(
                    alloc,
                    Instruction{ .load = instruction.value.Load{ .reg_index = idx } },
                );
            } else {
                return error.VariableNotFound;
            }
            return;
        },
    };

    if (instruction.getExpressionIndex(op)) |_| {
        for (tmp.data.list.items[1..]) |child| {
            try compile(state, child, instructions, alloc);
        }

        if (instruction.compile(state, tmp)) |instr| {
            try instructions.append(alloc, instr);
        } else |err| {
            log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
            return error.CompilationError;
        }
    } else if (std.mem.eql(u8, "let", op)) {
        const bindings = tmp.data.list.items[1].data.list;
        const expr = tmp.data.list.items[2];

        var i: usize = 0;
        while (i < bindings.items.len) {
            const name = bindings.items[i].data.id;
            const value = bindings.items[i + 1].data.num;
            const reg_index = state.reg_index;
            state.reg_index += 1;

            try state.env.put(name, reg_index);
            try instructions.append(alloc, Instruction{
                .value = instruction.value.Push{ .value = value },
            });
            try instructions.append(alloc, Instruction{
                .store = instruction.value.Store{ .reg_index = reg_index },
            });

            i += 2;
        }

        try compile(state, expr, instructions, alloc);

        i = 0;
        while (i < bindings.items.len) {
            const name = bindings.items[i].data.id;
            const reg_index = state.reg_index;
            state.reg_index += 1;

            _ = state.env.remove(name);
            try instructions.append(alloc, Instruction{
                .free = instruction.value.Free{ .reg_index = reg_index },
            });

            i += 2;
        }
    }
}

pub fn eval(state: *EngineState, instructions: []const Instruction) !void {
    state.stack_head = 0;
    for (instructions) |instr| {
        switch (instr) {
            inline else => |device| device.eval(state),
        }
    }
}
