const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerState = compiler.CompilerState;

const parser = @import("../parser.zig");
const Node = parser.Node;

const SpecialFn = *const fn (*CompilerState, *Node) anyerror!bool;

const letBlock = @import("special/let.zig");

pub const Specials = std.StaticStringMap(SpecialFn).initComptime(.{
    .{ "let", letBlock.expand },
});
