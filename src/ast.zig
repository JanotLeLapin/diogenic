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
};

pub const Operation = enum {
    Add,
    Sub,
    Mul,
    Div,

    pub fn fromIdent(id: []const u8) ?Operation {
        return operationMap.get(id);
    }
};

pub const Instruction = union(enum) {
    Operation: Operation,
    Value: f32,

    pub fn format(
        self: Instruction,
        writer: anytype,
    ) !void {
        switch (self) {
            .Operation => {
                try writer.print("op: {s}", .{@tagName(self.Operation)});
            },
            .Value => {
                try writer.print("val: {d}", .{self.Value});
            },
        }
    }
};

const operationMap = std.StaticStringMap(Operation).initComptime(.{
    .{ "+", Operation.Add },
    .{ "-", Operation.Sub },
    .{ "*", Operation.Mul },
    .{ "/", Operation.Div },
});
