const std = @import("std");

const root = @import("root.zig");

const ast = @import("ast.zig");
const parser = @import("parser.zig");
const compiler = @import("compiler.zig");

const engine = @import("dsp/engine.zig");

pub fn main() !void {
    const src = "(sine (+ 220.0 (* 16.0 (sine 0.6 0.0))) 0.0)";

    var t = parser.Tokenizer{ .src = src };

    const gpa = std.heap.page_allocator;
    var ast_arena = std.heap.ArenaAllocator.init(gpa);
    defer ast_arena.deinit();

    const ast_arena_alloc = ast_arena.allocator();

    const node = try parser.parse(ast_arena_alloc, gpa, &t);

    std.debug.print("tree:\n", .{});
    try root.walk_ast(node, 0);

    var instr_arena = std.heap.ArenaAllocator.init(gpa);
    defer instr_arena.deinit();

    const instr_arena_alloc = instr_arena.allocator();

    var res = try compiler.compile_expr(node.data.Expr.children.getLast(), instr_arena_alloc, gpa);
    defer res.deinit(instr_arena_alloc);

    std.debug.print("rpn:\n", .{});
    for (res.items) |instr| {
        std.debug.print("{f}\n", .{instr});
    }

    var e = engine.Engine.init();
    try root.render_wav32("out.wav", res, &e, 22500, gpa, gpa);
}
