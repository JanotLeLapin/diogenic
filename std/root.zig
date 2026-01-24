const std = @import("std");

pub const Standard = std.StaticStringMap([:0]const u8).initComptime(.{
    .{ "std/builtin", @embedFile("builtin.scm") },
});
