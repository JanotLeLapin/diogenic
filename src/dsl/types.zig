const std = @import("std");

pub const NodeType = enum {
    ident,
    value,
    atom,
    expr,
};

pub const Node = struct { text: ?[]const u8, children: ?std.ArrayList(*Node) };

pub const EdgeType = enum { osc, value };

pub const Edge = struct {
    type: EdgeType,
};
