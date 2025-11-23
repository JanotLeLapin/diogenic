const std = @import("std");

const ast = @import("ast.zig");
const compiler = @import("compiler.zig");
const instruction = @import("instruction.zig");
const parser = @import("parser.zig");

const block = @import("dsp/block.zig");
const engine = @import("dsp/engine.zig");

pub fn compileSource(
    src: []const u8,
    parser_ast_alloc: std.mem.Allocator,
    parser_stack_alloc: std.mem.Allocator,
    instr_res_alloc: std.mem.Allocator,
    instr_stack_alloc: std.mem.Allocator,
) !std.ArrayList(instruction.Instruction) {
    var t = parser.Tokenizer{ .src = src };

    const node = try parser.parse(parser_ast_alloc, parser_stack_alloc, &t);
    defer parser_ast_alloc.destroy(node);

    return compiler.compile_expr(node.data.Expr.children.getLast(), instr_res_alloc, instr_stack_alloc);
}

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
