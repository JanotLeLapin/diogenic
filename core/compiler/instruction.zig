const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerException = compiler.CompilerException;
const CompilerState = compiler.CompilerState;

const engine = @import("../engine.zig");

const instruction = @import("../instruction.zig");
const Instruction = instruction.Instruction;
const Instructions = instruction.Instructions;

const parser = @import("../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub fn expand(state: *CompilerState, node: *Node) anyerror!bool {
    const expr = switch (node.data) {
        .list => |lst| lst,
        else => unreachable,
    };

    const id = switch (expr.items[0].data) {
        .id => |id| id,
        else => unreachable,
    };

    // is this function is called we know the expression
    // actually exists
    const i = instruction.getExpressionIndex(id).?;

    switch (i) {
        inline 5...Instructions.len - 1 => |ci| {
            const T = Instructions[ci];

            var arg_slots: [T.args.len]?*Node = undefined;
            inline for (&arg_slots) |*slot| {
                slot.* = null;
            }

            var slot_idx: usize = 0;
            var maybe_name: ?[]const u8 = null;
            for (expr.items[1..]) |child| {
                if (maybe_name) |name| {
                    const arg_idx = blk: {
                        for (T.args, 0..) |arg, j| {
                            if (std.mem.eql(u8, name, arg.name)) {
                                break :blk j;
                            }
                        }

                        try state.exceptions.append(state.alloc.exception_alloc, .{
                            .exception = .unknown_arg,
                            .node = child,
                        });
                        return false;
                    };
                    arg_slots[arg_idx] = child;
                    maybe_name = null;
                } else {
                    switch (child.data) {
                        .atom => |atom| maybe_name = atom[1..],
                        else => {
                            while (slot_idx < arg_slots.len and arg_slots[slot_idx] != null) {
                                slot_idx += 1;
                            }

                            if (slot_idx >= arg_slots.len) {
                                try state.exceptions.append(state.alloc.exception_alloc, .{
                                    .exception = .bad_arity,
                                    .node = child,
                                });
                                return false;
                            }

                            if (T.args.len > 0) {
                                arg_slots[slot_idx] = child;
                            }

                            slot_idx += 1;
                        },
                    }
                }
            }

            if (maybe_name) |_| {
                try state.exceptions.append(state.alloc.exception_alloc, .{
                    .exception = .bad_arity,
                    .node = node,
                });
                return false;
            }

            const op = node.data.list.items[0];
            node.data.list.clearRetainingCapacity();
            try node.data.list.append(state.alloc.ast_alloc, op);
            for (arg_slots, T.args) |slot, arg| {
                if (slot) |child| {
                    try node.data.list.append(state.alloc.ast_alloc, child);
                } else {
                    if (arg.default) |default| {
                        const default_node = try state.alloc.ast_alloc.create(Node);
                        default_node.* = .{
                            .src = "DEFAULT",
                            .data = .{ .num = default },
                        };
                        try node.data.list.append(state.alloc.ast_alloc, default_node);
                    } else {
                        try state.exceptions.append(state.alloc.exception_alloc, .{
                            .exception = .bad_arity,
                            .node = node,
                        });
                    }
                }
            }
        },
        else => unreachable,
    }

    return true;
}

pub fn compile(node: *Node) anyerror!Instruction {
    const expr = switch (node.data) {
        .list => |lst| lst,
        else => unreachable,
    };

    const id = switch (expr.items[0].data) {
        .id => |id| id,
        else => unreachable,
    };

    const i = instruction.getExpressionIndex(id).?;

    switch (i) {
        inline 5...Instructions.len - 1 => |ci| {
            const T = Instructions[ci];

            const compile_data: engine.CompileData = .{
                .node = node,
            };

            return @unionInit(
                Instruction,
                T.name,
                try T.compile(compile_data),
            );
        },
        else => unreachable,
    }
}
