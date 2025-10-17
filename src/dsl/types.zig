const std = @import("std");

pub const Node = union(enum) {
    List: std.ArrayList(*Node),
    Symbol: []const u8,
};
