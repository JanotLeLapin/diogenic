const std = @import("std");

pub const Arg = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    default: ?f32 = null,
};
