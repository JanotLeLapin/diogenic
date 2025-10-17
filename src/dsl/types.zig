const std = @import("std");

pub const Node = union(enum) {
    List: std.ArrayList(*Node),
    Symbol: []const u8,
    Value: f32,
};

pub const EdgeType = enum { osc, value };

pub const Edge = struct {
    type: EdgeType,
};
