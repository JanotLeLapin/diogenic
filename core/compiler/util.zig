const std = @import("std");

const types = @import("types.zig");
const Function = types.Function;
const State = types.State;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub fn getExpr(node: *Node) ?struct {
    []const u8,
    []*Node,
} {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return null,
    };

    if (0 == expr.len) {
        return null;
    }

    const id = switch (expr[0].data) {
        .id => |id| id,
        else => return null,
    };

    return .{ id, expr[1..] };
}

pub fn reorderArgs(state: *State, node: *Node, f: *const Function) !void {
    _, const args = getExpr(node) orelse return;

    var arg_slots = try std.ArrayList(?*Node).initCapacity(
        state.stack_alloc,
        f.args.items.len,
    );
    defer arg_slots.deinit(state.stack_alloc);

    for (0..f.args.items.len) |_| {
        arg_slots.appendAssumeCapacity(null);
    }

    var slot_idx: usize = 0;
    var maybe_name: ?[]const u8 = null;
    for (args, 0..) |child, i| {
        if (maybe_name) |name| {
            const arg_idx = blk: {
                for (f.args.items, 0..) |arg, j| {
                    if (std.mem.eql(u8, name, arg)) {
                        break :blk j;
                    }
                }

                try state.pushException(.unknown_arg, args[i - 1], null);
                return;
            };

            arg_slots.items[arg_idx] = child;
            maybe_name = null;
        } else {
            switch (child.data) {
                .atom => |atom| {
                    maybe_name = atom[1..];
                    continue;
                },
                else => {},
            }

            while (slot_idx < arg_slots.items.len and arg_slots.items[slot_idx] != null) {
                slot_idx += 1;
            }

            if (slot_idx >= arg_slots.items.len) {
                try state.pushException(.bad_arity, child, null);
                return;
            }

            if (f.args.items.len > 0) {
                arg_slots.items[slot_idx] = child;
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

    for (arg_slots.items, f.args.items) |slot, arg_name| {
        const arg = f.arg_map.get(arg_name).?;
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
