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

pub fn compile(state: *CompilerState, root: *Node, alloc: std.mem.Allocator) !std.ArrayList(Instruction) {
    var pre_stack = try std.ArrayList(*Node).initCapacity(alloc, 32);
    defer pre_stack.deinit(alloc);

    var post_stack = try std.ArrayList(Instruction).initCapacity(alloc, 32);
    defer post_stack.deinit(alloc);

    try pre_stack.append(alloc, root);

    var has_error = false;
    while (pre_stack.items.len > 0) {
        const tmp = pre_stack.pop().?;
        const op = switch (tmp.data) {
            .list => |lst| lst.items[0].data.id,
            .num => |num| {
                try post_stack.append(
                    alloc,
                    Instruction{ .value = instruction.value.Push{ .value = num } },
                );
                continue;
            },
            .id => |id| {
                if (state.env.get(id)) |idx| {
                    try post_stack.append(
                        alloc,
                        Instruction{ .load = instruction.value.Load{ .reg_index = idx } },
                    );
                }
                continue;
            },
        };

        if (instruction.getExpressionIndex(op)) |_| {
            if (instruction.compile(state, tmp)) |instr| {
                try post_stack.append(alloc, instr);
            } else |err| {
                has_error = true;
                log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
                continue;
            }

            for (tmp.data.list.items) |child| {
                switch (child.data) {
                    .id => continue,
                    else => {},
                }

                try pre_stack.append(alloc, child);
            }
        } else if (std.mem.eql(u8, "let", op)) {}
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
