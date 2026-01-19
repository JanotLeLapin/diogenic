const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerState = compiler.CompilerState;

const parser = @import("../parser.zig");
const Node = parser.Node;

const MacroFn = *const fn (*CompilerState, *Node) anyerror!bool;

const letBlock = @import("special/let.zig");
const pipeBlock = @import("special/pipe.zig");

pub const Macros = std.StaticStringMap(MacroFn).initComptime(.{
    .{ "let", letBlock.expand },
    .{ "->", pipeBlock.expand },
});
