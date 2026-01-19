const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerExceptionData = compiler.CompilerExceptionData;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const State = struct {
    exceptions: *std.ArrayList(CompilerExceptionData),
    exceptions_alloc: std.mem.Allocator,
    ast_alloc: std.mem.Allocator,
};

const MacroFn = *const fn (*const State, *Node) anyerror!bool;

const pipeBlock = @import("macro/pipe.zig");

const Macros = std.StaticStringMap(MacroFn).initComptime(.{
    .{ "->", pipeBlock.expand },
});

pub fn expand(state: *const State, node: *Node) !bool {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return true,
    };

    if (0 == expr.len) {
        return true;
    }

    switch (expr[0].data) {
        .id => |op| {
            if (Macros.get(op)) |macro| {
                if (!try macro(state, node)) {
                    return false;
                }

                return expand(state, node);
            }
        },
        else => {},
    }

    var failed = false;
    for (expr[0..]) |child| {
        if (!try expand(state, child)) {
            failed = true;
        }
    }

    return !failed;
}
