const std = @import("std");

const ast = @import("ast.zig");

pub const InstructionError = error{
    NotFound,
    BadArity,
};

const Validate = fn (ast.NodeDataExpression) InstructionError!void;

fn genValidate(comptime arity: comptime_int) Validate {
    return struct {
        fn validate(expr: ast.NodeDataExpression) InstructionError!void {
            if (expr.children.items.len != arity) {
                return InstructionError.BadArity;
            }
        }
    }.validate;
}

pub const ArithmeticOperation = enum {
    Add,
    Sub,
    Mul,
    Div,

    fn validate(expr: ast.NodeDataExpression) InstructionError!void {
        return genValidate(2)(expr);
    }
};

pub const FilterOperationType = enum {
    High,
    Low,
};

pub const FilterOperation = struct {
    t: FilterOperationType,
    tmp_slot: usize,

    fn validate(expr: ast.NodeDataExpression) InstructionError!void {
        return genValidate(4)(expr);
    }
};

pub const MathOperation = enum {
    Log2,
    Log10,
    Logn,

    Atan,
    Exp,
    Exp2,

    MidiToFreq,
    FreqToMidi,
    DbToAmp,
    AmpToDb,

    fn validate(expr: ast.NodeDataExpression) InstructionError!void {
        return genValidate(1)(expr);
    }
};

pub const NoiseOperation = enum {
    White,

    fn validate(expr: ast.NodeDataExpression) InstructionError!void {
        return genValidate(0)(expr);
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

    fn validate(expr: ast.NodeDataExpression) InstructionError!void {
        return genValidate(2)(expr);
    }
};

pub const ShaperOperation = enum {
    Clamp,
    Clip,
    Diode,
    Quantize,

    fn validate(expr: ast.NodeDataExpression) InstructionError!void {
        return genValidate(2)(expr);
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

    fn validate(instr: Instruction, expr: ast.NodeDataExpression) InstructionError!void {
        const active_tag = std.meta.activeTag(instr);

        inline for (std.meta.fields(Instruction)) |field| {
            if (comptime std.mem.eql(u8, field.name, "Value")) {
                if (active_tag == .Value) {
                    return;
                }
            } else if (@field(std.meta.Tag(Instruction), field.name) == active_tag) {
                return field.type.validate(expr);
            }
        }

        unreachable;
    }

    pub fn fromExpr(expr: ast.NodeDataExpression, current_slot: *usize) InstructionError!Instruction {
        var instr = InstructionMap.get(expr.op) orelse return InstructionError.NotFound;
        try instr.validate(expr);

        switch (instr) {
            .Filter => {
                instr.Filter.tmp_slot = current_slot.*;
                current_slot.* += 4;
            },
            .Osc => {
                instr.Osc.phase_slot = current_slot.*;
                current_slot.* += 1;
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
    .{ "midi->freq", Instruction{ .Math = MathOperation.MidiToFreq } },
    .{ "freq->midi", Instruction{ .Math = MathOperation.FreqToMidi } },
    .{ "db->amp", Instruction{ .Math = MathOperation.DbToAmp } },
    .{ "amp->db", Instruction{ .Math = MathOperation.AmpToDb } },

    .{ "white-noise", Instruction{ .Noise = NoiseOperation.White } },

    .{ "sawtooth", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sawtooth, .phase_slot = 0 } } },
    .{ "sine", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sine, .phase_slot = 0 } } },
    .{ "square", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Square, .phase_slot = 0 } } },

    .{ "clamp", Instruction{ .Shaper = ShaperOperation.Clamp } },
    .{ "clip", Instruction{ .Shaper = ShaperOperation.Clip } },
    .{ "diode", Instruction{ .Shaper = ShaperOperation.Diode } },
    .{ "quantize", Instruction{ .Shaper = ShaperOperation.Quantize } },
});
