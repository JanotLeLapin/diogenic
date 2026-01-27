const std = @import("std");

const types = @import("../types.zig");
const State = types.State;

const parser = @import("../../parser.zig");
const Node = parser.Node;

pub fn expand(state: *const State, node: *Node) anyerror!void {
    var prev = node.data.list.items[1];
    for (2..node.data.list.items.len) |i| {
        try node.data.list.items[i].data.list.insert(state.arena_alloc, 1, prev);
        prev = node.data.list.items[i];
    }
    node.data = prev.data;
}
