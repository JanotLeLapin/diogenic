const std = @import("std");
const log = std.log.scoped(.compiler);

const builtin = @import("builtin");

const engine = @import("engine.zig");
const CompilerState = engine.CompilerState;

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;

const is_freestanding = builtin.target.os.tag == .freestanding;

pub const Constants = std.StaticStringMap(f32).initComptime(.{
    .{ "PI", std.math.pi },
});

pub fn compile(state: *CompilerState, tmp: *Node, instructions: *std.ArrayList(Instruction), alloc: std.mem.Allocator) !void {
    const op = switch (tmp.data) {
        .list => |lst| lst.items[0].data.id,
        .num => |num| {
            try instructions.append(
                alloc,
                Instruction{ .push = instruction.value.Push{ .value = num } },
            );
            return;
        },
        .id => |id| {
            if (state.env.get(id)) |idx| {
                try instructions.append(
                    alloc,
                    Instruction{ .load = instruction.value.Load{ .reg_index = idx } },
                );
            } else if (Constants.get(id)) |v| {
                try instructions.append(
                    alloc,
                    Instruction{ .push = instruction.value.Push{ .value = v } },
                );
            } else {
                if (!is_freestanding) {
                    log.err("VariableNotFound: could not resolve '{s}'", .{tmp.src});
                }
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
            if (!is_freestanding) {
                log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
            }
            return error.CompilationError;
        }
    } else if (std.mem.eql(u8, "let", op)) {
        const bindings = tmp.data.list.items[1].data.list;
        const expr = tmp.data.list.items[2];

        var i: usize = 0;
        while (i < bindings.items.len) {
            const name = bindings.items[i].data.id;
            const reg_index = state.reg_index;
            state.reg_index += 1;

            try state.env.put(name, reg_index);
            try compile(state, bindings.items[i + 1], instructions, alloc);
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
    } else {
        if (!is_freestanding) {
            log.err("UnknownExpression: could not compile '{s}'", .{tmp.src});
        }
        return error.UnknownExpression;
    }
}
