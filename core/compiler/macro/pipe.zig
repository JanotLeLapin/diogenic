const std = @import("std");

const State = @import("../macro.zig").State;

const parser = @import("../../parser.zig");
const Node = parser.Node;

pub fn expand(state: *const State, tmp: *Node) anyerror!bool {
    var expr = tmp.data.list.items[1];
    for (2..tmp.data.list.items.len) |i| {
        try tmp.data.list.items[i].data.list.insert(state.ast_alloc, 1, expr);
        expr = tmp.data.list.items[i];
    }
    tmp.data = expr.data;

    return true;
}
