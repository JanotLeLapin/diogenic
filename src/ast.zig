const std = @import("std");

pub const NodeDataExpression = struct {
    op: []const u8,
    children: std.ArrayList(*Node),
};

pub const NodeData = union(enum) {
    Expr: NodeDataExpression,
    Ident: []const u8,
    Atom: []const u8,
    Value: f32,
};

pub const Node = struct {
    visited: bool,
    data: NodeData,
    src: []const u8,
};
