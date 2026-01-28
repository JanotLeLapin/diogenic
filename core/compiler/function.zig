const std = @import("std");

const types = @import("types.zig");
const Function = types.Function;
const Module = types.Module;
const State = types.State;

const parser = @import("../parser.zig");
const Node = parser.Node;

fn resolveFunction(mod: *Module, expr: []*Node) ?Function {
    if (1 > expr.len) {
        return null;
    }

    const op = switch (expr[0].data) {
        .id => |id| id,
        else => return null,
    };

    return mod.getFunction(op);
}

fn expandFunction(state: *State, node: *Node, func: Function) !void {
    const expr = node.data.list.items;

    const let_bindings_node = blk: {
        var lst = try std.ArrayList(*Node).initCapacity(
            state.arena_alloc,
            2 * func.args.items.len,
        );

        for (func.args.items, expr[1..]) |func_arg_name, param| {
            const func_arg = func.arg_map.get(func_arg_name).?;
            try lst.append(state.arena_alloc, func_arg.id_node);
            try lst.append(state.arena_alloc, param);
        }

        const let_bindings_node = try state.arena_alloc.create(Node);
        let_bindings_node.* = .{
            .data = .{
                .list = lst,
            },
            .src = "_",
            .src_file = node.src_file,
            .pos = node.pos,
        };

        break :blk let_bindings_node;
    };

    const let_node_list = blk: {
        var lst = try std.ArrayList(*Node).initCapacity(
            state.arena_alloc,
            3,
        );

        const name = try state.arena_alloc.create(Node);
        name.* = .{
            .data = .{ .id = "let" },
            .src = "_",
            .src_file = node.src_file,
            .pos = node.pos,
        };

        try lst.append(state.arena_alloc, name);
        try lst.append(state.arena_alloc, let_bindings_node);
        try lst.append(state.arena_alloc, func.body);

        break :blk lst;
    };

    node.data = .{ .list = let_node_list };
}

fn expandModule(state: *State, mod: *Module, node: *Node) !void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return,
    };

    for (expr) |child| {
        try expandModule(state, mod, child);
    }

    if (resolveFunction(mod, expr)) |func| {
        try expandFunction(state, node, func);
    }
}

pub fn expand(state: *State, mod: *Module) !void {
    try expandModule(state, mod, mod.root);
    var iter = state.map.valueIterator();
    while (iter.next()) |it_mod| {
        try expandModule(state, it_mod.*, it_mod.*.root);
    }
}
