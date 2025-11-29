const std = @import("std");

const ast = @import("ast.zig");
const compiler = @import("compiler.zig");
const ir = @import("ir.zig");
const instruction = @import("instruction.zig");
const parser = @import("parser.zig");

const block = @import("dsp/block.zig");
const engine = @import("dsp/engine.zig");

pub fn compileSource(
    src: []const u8,
    parser_alloc: parser.ParserAlloc,
    compiler_alloc: compiler.CompilerAlloc,
) !ir.InterRepr {
    var t = parser.Tokenizer{ .src = src };

    const node = try parser.parse(&t, parser_alloc);
    defer parser_alloc.ast_alloc.destroy(node);

    return compiler.compileExpr(node.data.Expr.children.getLast(), compiler_alloc);
}

pub fn renderBlock(
    inter_repr: ir.InterRepr,
    e: *engine.Engine,
    out: []f32,
    out_offset: usize,
) !void {
    const res = try e.eval(inter_repr);
    for (0..block.BLOCK_LENGTH) |i| {
        out[out_offset + i * 2] = res.get(0, i);
        out[out_offset + i * 2 + 1] = res.get(1, i);
    }
}

pub fn walkAst(node: *ast.Node, depth: usize) !void {
    switch (node.data) {
        .Expr => {
            for (0..depth) |_| {
                std.debug.print(" ", .{});
            }
            std.debug.print("expr: {s}\n", .{node.data.Expr.op});
            for (node.data.Expr.children.items) |child| {
                try walkAst(child, depth + 1);
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
