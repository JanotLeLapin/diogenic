const std = @import("std");

const root = @import("root.zig");

const ast = @import("ast.zig");
const parser = @import("parser.zig");
const compiler = @import("compiler.zig");

const engine = @import("dsp/engine.zig");

pub fn main() !void {
    const src = "(sine (+ 220.0 (* 16.0 (sine 0.6 0.0))) 0.0)";

    const gpa = std.heap.page_allocator;

    var instr_arena = std.heap.ArenaAllocator.init(gpa);
    defer instr_arena.deinit();

    const instr_arena_alloc = instr_arena.allocator();

    const instr = insr: {
        var t = parser.Tokenizer{ .src = src };

        var ast_arena = std.heap.ArenaAllocator.init(gpa);
        defer ast_arena.deinit();

        const ast_arena_alloc = ast_arena.allocator();

        const node = try parser.parse(ast_arena_alloc, gpa, &t);

        std.debug.print("tree:\n", .{});
        try root.walk_ast(node, 0);

        break :insr try compiler.compile_expr(node.data.Expr.children.getLast(), instr_arena_alloc, gpa);
    };

    std.debug.print("rpn:\n", .{});
    for (instr.items) |item| {
        std.debug.print("{f}\n", .{item});
    }

    var e = try engine.Engine.init(gpa);
    try root.render_wav32("out.wav", instr, &e, 22500, gpa);
}
