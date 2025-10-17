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

fn BinaryOp(comptime variant: []const u8) type {
    return struct {
        lhs: Expression,
        rhs: Expression,

        pub fn compile(gpa: std.mem.Allocator, node: *types.Node, ctx: *Context) !Expression {
            const lhs = try Expression.compile(gpa, node.List.items[1], ctx);
            const rhs = try Expression.compile(gpa, node.List.items[2], ctx);

            const self = try gpa.create(@This());
            self.* = .{ .lhs = lhs, .rhs = rhs };
            return @unionInit(Expression, variant, self);
        }
    };
}

fn UnaryOp(comptime variant: []const u8) type {
    return struct {
        input: Expression,

        pub fn compile(gpa: std.mem.Allocator, node: *types.Node, ctx: *Context) !Expression {
            const input = try Expression.compile(gpa, node.List.items[1], ctx);

            const self = try gpa.create(@This());
            self.* = .{ .input = input };
            return @unionInit(Expression, variant, self);
        }
    };
}

const Add = BinaryOp("Add");
const Mul = BinaryOp("Mul");
const Min = BinaryOp("Min");
const Max = BinaryOp("Max");
const Quantize = BinaryOp("Quantize");

const Logn = UnaryOp("Logn");
const Log2 = UnaryOp("Log2");
const Exp = UnaryOp("Exp");
const FreqToMidi = UnaryOp("FreqToMidi");
const MidiToFreq = UnaryOp("MidiToFreq");

const CompileFn = *const fn (gpa: std.mem.Allocator, node: *types.Node, context: *Context) anyerror!Expression;

pub const Expression = union(enum) {
    Literal: *Literal,
    Add: *Add,
    Mul: *Mul,
    Min: *Min,
    Max: *Max,
    Quantize: *Quantize,
    Logn: *Logn,
    Log2: *Log2,
    Exp: *Exp,
    FreqToMidi: *FreqToMidi,
    MidiToFreq: *MidiToFreq,

    pub fn compile(gpa: std.mem.Allocator, node: *types.Node, context: *Context) !Expression {
        return switch (node.*) {
            .Symbol => {
                return try Literal.compile(gpa, node, context);
            },
            .List => {
                const fn_name = node.List.items[0].Symbol;
                const compile_fn = compilers.get(fn_name).?;
                return compile_fn(gpa, node, context);
            },
        };
    }
};

const compilers = std.StaticStringMap(CompileFn).initComptime(.{
    .{ "+", Add.compile },
    .{ "*", Mul.compile },
    .{ "min", Min.compile },
    .{ "max", Max.compile },
    .{ "quantize", Quantize.compile },
    .{ "logn", Logn.compile },
    .{ "log2", Log2.compile },
    .{ "exp", Exp.compile },
    .{ "freq->midi", FreqToMidi.compile },
    .{ "midi->freq", MidiToFreq.compile },
});
