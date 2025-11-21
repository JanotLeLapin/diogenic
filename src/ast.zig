const std = @import("std");

pub const NodeData = union(enum) {
    Expr: std.ArrayList(*Node),
    Ident: []const u8,
    Atom: []const u8,
    Value: f32,
};

pub const Node = struct {
    visited: bool,
    data: NodeData,
};
