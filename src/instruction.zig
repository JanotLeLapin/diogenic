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

pub const OscOperationType = enum {
    Sine,
    Square,
};

pub const OscOperation = struct {
    t: OscOperationType,
    phase_slot: usize,
};

pub const ShaperOperation = enum {
    Clip,
    Quantize,
};

pub const Instruction = union(enum) {
    Arith: ArithmeticOperation,
    Math: MathOperation,
    Osc: OscOperation,
    Shaper: ShaperOperation,
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
            .Osc => {
                try writer.print("osc: {s}", .{@tagName(self.Osc.t)});
            },
            .Shaper => {
                try writer.print("shaper: {s}", .{@tagName(self.Shaper)});
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

    .{ "sine", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sine, .phase_slot = 0 } } },
    .{ "square", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Square, .phase_slot = 0 } } },

    .{ "clip", Instruction{ .Shaper = ShaperOperation.Clip } },
    .{ "quantize", Instruction{ .Shaper = ShaperOperation.Quantize } },
});
