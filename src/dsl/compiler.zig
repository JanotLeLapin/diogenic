const std = @import("std");
const types = @import("types.zig");

const Context = std.StringHashMap(Expression);

const Literal = struct {
    value: f32,

    pub fn compile(gpa: std.mem.Allocator, node: *types.Node, _: *Context) !Expression {
        const self = try gpa.create(Literal);
        self.* = .{ .value = try std.fmt.parseFloat(f32, node.Symbol) };
        return .{ .Literal = self };
    }
};

const Add = struct {
    lhs: Expression,
    rhs: Expression,

    pub fn compile(gpa: std.mem.Allocator, node: *types.Node, ctx: *Context) !Expression {
        const lhs = try Expression.compile(gpa, node.List.items[1], ctx);
        const rhs = try Expression.compile(gpa, node.List.items[2], ctx);

        const self = try gpa.create(Add);
        self.* = .{ .lhs = lhs, .rhs = rhs };
        return .{ .Add = self };
    }
};

const CompileFn = *const fn (gpa: std.mem.Allocator, node: *types.Node, context: *Context) anyerror!Expression;

pub const Expression = union(enum) {
    Literal: *Literal,
    Add: *Add,

    pub fn compile(gpa: std.mem.Allocator, node: *types.Node, context: *Context) !Expression {
        return switch (node.*) {
            .Symbol => {
                return try Literal.compile(gpa, node, context);
            },
            .List => {
                const fn_name = node.List.items[0].Symbol;
                std.debug.print("Compiling {s}\n", .{fn_name});
                const compile_fn = compilers.get(fn_name).?;
                return compile_fn(gpa, node, context);
            },
        };
    }
};

const compilers = std.StaticStringMap(CompileFn).initComptime(.{
    .{ "+", Add.compile },
});
