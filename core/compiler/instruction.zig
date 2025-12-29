const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerError = compiler.CompilerError;

const engine = @import("../engine.zig");

const instruction = @import("../instruction.zig");
const Instruction = instruction.Instruction;
const Instructions = instruction.Instructions;

const parser = @import("../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub fn expand(node: *Node, alloc: std.mem.Allocator) CompilerError!void {
    const expr = switch (node.data) {
        .list => |lst| lst,
        else => return,
    };

    const id = switch (expr.items[0].data) {
        .id => |id| id,
        else => return,
    };

    const i = instruction.getExpressionIndex(id) orelse return error.UnknownExpr;

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
                        return error.UnknownArg;
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
                                return error.BadArity;
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
                return error.BadArity;
            }

            const op = node.data.list.items[0];
            node.data.list.clearRetainingCapacity();
            node.data.list.append(alloc, op) catch unreachable; // FIXME: handle this
            for (arg_slots, T.args) |slot, arg| {
                if (slot) |child| {
                    node.data.list.append(alloc, child) catch unreachable; // FIXME: handle this
                } else {
                    if (arg.default) |default| {
                        const default_node = alloc.create(Node) catch unreachable; // FIXME: handle this
                        default_node.* = .{
                            .src = "DEFAULT",
                            .data = .{ .num = default },
                        };
                        node.data.list.append(alloc, default_node) catch unreachable; // FIXME: handle this
                    } else {
                        return error.BadArity;
                    }
                }
            }
        },
        else => unreachable,
    }
}

pub fn compile(node: *Node) CompilerError!Instruction {
    const expr = switch (node.data) {
        .list => |lst| lst,
        else => return error.BadExpr,
    };

    const id = switch (expr.items[0].data) {
        .id => |id| id,
        else => return error.BadExpr,
    };

    const i = instruction.getExpressionIndex(id) orelse return error.UnknownExpr;

    switch (i) {
        inline 5...Instructions.len - 1 => |ci| {
            const T = Instructions[ci];

            const compile_data: engine.CompileData = .{
                .node = node,
            };

            return @unionInit(
                Instruction,
                T.name,
                T.compile(compile_data) catch unreachable, // FIXME: handle this
            );
        },
        else => unreachable,
    }
}
