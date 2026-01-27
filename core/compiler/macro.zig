const std = @import("std");

const types = @import("types.zig");
const State = types.State;

const parser = @import("../parser.zig");
const Node = parser.Node;

const MacroHook = *const fn (*const State, *Node) anyerror!void;

const Macros = std.StaticStringMap(MacroHook).initComptime((.{
    .{ "->", &@import("macro/pipe.zig").expand },
}));

fn resolveMacro(expr: []*Node) ?MacroHook {
    if (1 > expr.len) {
        return null;
    }

    const op = switch (expr[0].data) {
        .id => |id| id,
        else => return null,
    };

    return Macros.get(op);
}

pub fn expand(state: *const State, node: *Node) !void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return,
    };

    if (resolveMacro(expr)) |macro_hook| {
        try macro_hook(state, node);
        try expand(state, node);
    } else {
        for (expr) |child| {
            try expand(state, child);
        }
    }
}
