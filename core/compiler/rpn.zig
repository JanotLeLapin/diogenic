const std = @import("std");

const types = @import("types.zig");
const State = types.State;

const engine = @import("../engine.zig");
const CompileData = engine.CompileData;

const instr = @import("../instruction.zig");
const Instr = instr.Instruction;
const Instrs = instr.Instructions;

const Specials = @import("special.zig").Specials;

const parser = @import("../parser.zig");
const Node = parser.Node;

const Constants = std.StaticStringMap(f32).initComptime(.{
    .{ "E", std.math.e },
    .{ "PI", std.math.pi },
    .{ "PHI", std.math.phi },
    .{ "INF", std.math.inf(f32) },
});

fn reorderExprArgs(state: *State, node: *Node, comptime T: type) !void {
    var lst = switch (node.data) {
        .list => |lst| lst,
        else => return,
    };
    const args = lst.items[1..];

    var arg_slots: [T.args.len]?*Node = undefined;
    inline for (&arg_slots) |*slot| {
        slot.* = null;
    }

    var slot_idx: usize = 0;
    var maybe_name: ?[]const u8 = null;
    for (args, 0..) |child, i| {
        if (maybe_name) |name| {
            const arg_idx = blk: {
                for (T.args, 0..) |arg, j| {
                    if (std.mem.eql(u8, name, arg.name)) {
                        break :blk j;
                    }
                }

                try state.pushException(.unknown_arg, args[i - 1], null);
                return;
            };

            arg_slots[arg_idx] = child;
            maybe_name = null;
        } else {
            switch (child.data) {
                .atom => |atom| {
                    maybe_name = atom[1..];
                    continue;
                },
                else => {},
            }

            while (slot_idx < arg_slots.len and arg_slots[slot_idx] != null) {
                slot_idx += 1;
            }

            if (slot_idx >= arg_slots.len) {
                try state.pushException(.bad_arity, child, null);
                return;
            }

            if (T.args.len > 0) {
                arg_slots[slot_idx] = child;
            }

            slot_idx += 1;
        }
    }

    if (maybe_name) |_| {
        try state.pushException(.bad_arity, args[args.len - 1], null);
        return;
    }

    const op = node.data.list.items[0];
    node.data.list.clearRetainingCapacity();
    try node.data.list.append(state.arena_alloc, op);

    for (arg_slots, T.args) |slot, arg| {
        if (slot) |child| {
            try node.data.list.append(state.arena_alloc, child);
        } else {
            if (arg.default) |default| {
                const default_node = try state.arena_alloc.create(Node);
                default_node.* = .{
                    .data = .{ .num = default },
                    .src = "_",
                    .src_file = node.src_file,
                    .pos = node.pos,
                };
                try node.data.list.append(state.arena_alloc, default_node);
            } else {
                try state.pushException(.bad_arity, node, "missing required argument");
                return;
            }
        }
    }
}

fn compileExpr(d: CompileData, comptime T: type) anyerror!Instr {
    return @unionInit(Instr, T.name, try T.compile(d));
}

pub fn expand(state: *State, node: *Node) anyerror!void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        .num => |num| {
            try state.pushInstr(Instr{
                ._push = instr.value.Push{ .value = num },
            });
            return;
        },
        .id => |id| {
            if (state.env.get(id)) |reg| {
                try state.pushInstr(Instr{
                    ._load = instr.value.Load{ .reg_index = reg },
                });
            } else if (Constants.get(id)) |v| {
                try state.pushInstr(.{
                    ._push = instr.value.Push{ .value = v },
                });
            } else {
                try state.pushException(.unresolved_symbol, node, "unknown expression");
            }
            return;
        },
        else => {
            try state.pushException(.unresolved_symbol, node, "unknown expression");
            return;
        },
    };

    if (1 > expr.len) {
        try state.pushException(.bad_expr, node, "empty expression");
        return;
    }

    const op = switch (expr[0].data) {
        .id => |id| id,
        else => {
            try state.pushException(.unexpected_arg, expr[0], "expected ident");
            return;
        },
    };

    if (instr.getExpressionIndex(op)) |idx| {
        switch (idx) {
            inline 5...Instrs.len - 1 => |i| {
                const T = Instrs[i];
                try reorderExprArgs(state, node, T);

                for (node.data.list.items[1..]) |child| {
                    try expand(state, child);
                }

                const d: CompileData = .{
                    .alloc = state.instr_alloc,
                    .node = node,
                };

                const instruction = try compileExpr(d, T);
                try state.pushInstr(instruction);
            },
            else => unreachable,
        }
    } else if (Specials.get(op)) |hook| {
        try hook(state, node);
    } else {
        try state.pushException(.unknown_expr, expr[0], null);
        return;
    }
}
