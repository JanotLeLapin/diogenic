const std = @import("std");

const types = @import("types.zig");
const State = types.State;

const parser = @import("../parser.zig");
const Node = parser.Node;

const SpecialHook = *const fn (*State, *Node) anyerror!void;

pub const Specials = std.StaticStringMap(SpecialHook).initComptime(.{
    .{ "let", @import("special/let.zig").expand },
});
