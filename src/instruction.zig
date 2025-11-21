const std = @import("std");

pub const ArithmeticOperation = enum {
    Add,
    Sub,
    Mul,
    Div,
};

pub const MathOperation = enum {
    Log2,
    Log10,
    Logn,
};

pub const Instruction = union(enum) {
    Arith: ArithmeticOperation,
    Math: MathOperation,
    Value: f32,

    pub fn fromIdent(id: []const u8) ?Instruction {
        return InstructionMap.get(id);
    }

    pub fn format(
        self: Instruction,
        writer: anytype,
    ) !void {
        switch (self) {
            .Arith => {
                try writer.print("arith: {s}", .{@tagName(self.Arith)});
            },
            .Math => {
                try writer.print("math: {s}", .{@tagName(self.Math)});
            },
            .Value => {
                try writer.print("val: {d}", .{self.Value});
            },
        }
    }
};

const InstructionMap = std.StaticStringMap(Instruction).initComptime(.{
    .{ "+", Instruction{ .Arith = ArithmeticOperation.Add } },
    .{ "-", Instruction{ .Arith = ArithmeticOperation.Sub } },
    .{ "*", Instruction{ .Arith = ArithmeticOperation.Mul } },
    .{ "/", Instruction{ .Arith = ArithmeticOperation.Div } },

    .{ "log2", Instruction{ .Math = MathOperation.Log2 } },
    .{ "log10", Instruction{ .Math = MathOperation.Log10 } },
    .{ "logn", Instruction{ .Math = MathOperation.Logn } },
});
