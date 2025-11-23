const std = @import("std");

const ast = @import("ast.zig");

pub const ArithmeticOperation = enum {
    Add,
    Sub,
    Mul,
    Div,

    fn validate(expr: ast.NodeDataExpression) bool {
        return expr.children.items.len == 2;
    }
};

pub const FilterOperationType = enum {
    High,
    Low,
};

pub const FilterOperation = struct {
    t: FilterOperationType,
    tmp_slot: usize,

    fn validate(expr: ast.NodeDataExpression) bool {
        return expr.children.items.len == 4;
    }
};

pub const MathOperation = enum {
    Log2,
    Log10,
    Logn,

    Atan,
    Exp,
    Exp2,

    fn validate(expr: ast.NodeDataExpression) bool {
        return expr.children.items.len == 1;
    }
};

pub const NoiseOperation = enum {
    White,

    fn validate(expr: ast.NodeDataExpression) bool {
        return expr.children.items.len == 0;
    }
};

pub const OscOperationType = enum {
    Sawtooth,
    Sine,
    Square,
};

pub const OscOperation = struct {
    t: OscOperationType,
    phase_slot: usize,

    fn validate(expr: ast.NodeDataExpression) bool {
        return expr.children.items.len == 2;
    }
};

pub const ShaperOperation = enum {
    Clamp,
    Clip,
    Diode,
    Quantize,

    fn validate(expr: ast.NodeDataExpression) bool {
        return expr.children.items.len == 2;
    }
};

pub const Instruction = union(enum) {
    Arith: ArithmeticOperation,
    Filter: FilterOperation,
    Math: MathOperation,
    Noise: NoiseOperation,
    Osc: OscOperation,
    Shaper: ShaperOperation,
    Value: f32,

    pub fn fromExpr(expr: ast.NodeDataExpression, current_slot: *usize) ?Instruction {
        var instr = InstructionMap.get(expr.op) orelse return null;

        switch (instr) {
            .Arith => {
                if (!ArithmeticOperation.validate(expr)) {
                    return null;
                }
            },
            .Filter => {
                if (!FilterOperation.validate(expr)) {
                    return null;
                }
                instr.Filter.tmp_slot = current_slot.*;
                current_slot.* += 4;
            },
            .Math => {
                if (!MathOperation.validate(expr)) {
                    return null;
                }
            },
            .Noise => {
                if (!NoiseOperation.validate(expr)) {
                    return null;
                }
            },
            .Osc => {
                if (!OscOperation.validate(expr)) {
                    return null;
                }
                instr.Osc.phase_slot = current_slot.*;
                current_slot.* += 1;
            },
            .Shaper => {
                if (!ShaperOperation.validate(expr)) {
                    return null;
                }
            },
            else => {},
        }
        return instr;
    }

    pub fn format(
        self: Instruction,
        writer: anytype,
    ) !void {
        switch (self) {
            .Arith => {
                try writer.print("arith: {s}", .{@tagName(self.Arith)});
            },
            .Filter => {
                try writer.print("filter: {s}", .{@tagName(self.Filter.t)});
            },
            .Math => {
                try writer.print("math: {s}", .{@tagName(self.Math)});
            },
            .Noise => {
                try writer.print("noise: {s}", .{@tagName(self.Noise)});
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

    .{ "highpass", Instruction{ .Filter = FilterOperation{ .t = FilterOperationType.High, .tmp_slot = 0 } } },
    .{ "lowpass", Instruction{ .Filter = FilterOperation{ .t = FilterOperationType.Low, .tmp_slot = 0 } } },

    .{ "log2", Instruction{ .Math = MathOperation.Log2 } },
    .{ "log10", Instruction{ .Math = MathOperation.Log10 } },
    .{ "logn", Instruction{ .Math = MathOperation.Logn } },
    .{ "atan", Instruction{ .Math = MathOperation.Atan } },
    .{ "exp", Instruction{ .Math = MathOperation.Exp } },
    .{ "exp2", Instruction{ .Math = MathOperation.Exp2 } },

    .{ "white-noise", Instruction{ .Noise = NoiseOperation.White } },

    .{ "sawtooth", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sawtooth, .phase_slot = 0 } } },
    .{ "sine", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sine, .phase_slot = 0 } } },
    .{ "square", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Square, .phase_slot = 0 } } },

    .{ "clamp", Instruction{ .Shaper = ShaperOperation.Clamp } },
    .{ "clip", Instruction{ .Shaper = ShaperOperation.Clip } },
    .{ "diode", Instruction{ .Shaper = ShaperOperation.Diode } },
    .{ "quantize", Instruction{ .Shaper = ShaperOperation.Quantize } },
});
