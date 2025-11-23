const std = @import("std");

const ast = @import("ast.zig");
const instruction = @import("instruction.zig");

const block = @import("dsp/block.zig");
const engine = @import("dsp/engine.zig");

pub fn renderBlock(
    instructions: []instruction.Instruction,
    e: *engine.Engine,
    out: []f32,
    out_offset: usize,
) !void {
    const res = try e.eval(instructions);
    for (0..block.BLOCK_LENGTH) |i| {
        out[out_offset + i * 2] = res.get(0, i);
        out[out_offset + i * 2 + 1] = res.get(1, i);
    }
}

pub fn walk_ast(node: *ast.Node, depth: usize) !void {
    switch (node.data) {
        .Expr => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("expr: {s}\n", .{node.data.Expr.op});
            for (node.data.Expr.children.items) |child| {
                try walk_ast(child, depth + 1);
            }
        },
        .Ident => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("id: {s}\n", .{node.data.Ident});
            return;
        },
        .Atom => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("at: {s}\n", .{node.data.Atom});
            return;
        },
        .Value => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("vl: {d}\n", .{node.data.Value});
            return;
        },
    }
}
