const std = @import("std");

const ast = @import("ast.zig");

pub const InstructionError = error{
    NotFound,
    BadArity,
    BadArgument,
    MissingArgument,

    MemoryError,
};

const Arg = struct {
    pos: usize,
    default: ?f32,
};

const Validate = fn (*ast.NodeDataExpression) InstructionError!void;
const Linearize = fn (*ast.NodeDataExpression, std.mem.Allocator) InstructionError!void;

fn genValidate(comptime arity: comptime_int) Validate {
    return struct {
        fn validate(expr: *ast.NodeDataExpression) InstructionError!void {
            if (expr.children.items.len != arity) {
                return InstructionError.BadArity;
            }
        }
    }.validate;
}

fn genLinearize(comptime argmap: anytype) Linearize {
    const arg_count = argmap.keys().len;
    return struct {
        fn linearize(expr: *ast.NodeDataExpression, alloc: std.mem.Allocator) InstructionError!void {
            var args: [arg_count]?*ast.Node = .{null} ** arg_count;

            var i: usize = 0;
            while (i < expr.children.items.len) {
                const key_node = expr.children.items[i];
                switch (key_node.data) {
                    .Atom => {},
                    else => return InstructionError.BadArgument,
                }

                const arg = argmap.get(key_node.data.Atom) orelse return InstructionError.NotFound;
                args[arg.pos] = expr.children.items[i + 1];

                i += 2;
            }

            for (argmap.values()) |arg| {
                if (null == args[arg.pos]) {
                    const default = arg.default orelse return InstructionError.MissingArgument;
                    var node = alloc.create(ast.Node) catch return InstructionError.MemoryError;
                    node.src = "<DEFAULT>";
                    node.visited = false;
                    node.data = ast.NodeData{ .Value = default };
                    args[arg.pos] = node;
                }
            }

            expr.children.clearRetainingCapacity();
            for (args) |arg| {
                expr.children.append(alloc, arg.?) catch return InstructionError.MemoryError;
            }
        }
    }.linearize;
}

pub const ArithmeticOperation = enum {
    Add,
    Sub,
    Mul,
    Div,

    Lt,
    Leq,
    Gt,
    Geq,

    fn linearize(expr: *ast.NodeDataExpression, _: std.mem.Allocator) InstructionError!void {
        try genValidate(2)(expr);
    }
};

pub const FilterOperationType = enum {
    High,
    Low,
};

pub const FilterOperation = struct {
    t: FilterOperationType,
    tmp_slot: usize,

    const argmap = std.StaticStringMap(Arg).initComptime(.{
        .{ ":freq", Arg{ .default = null, .pos = 0 } },
        .{ ":quality", Arg{ .default = 0.707, .pos = 1 } },
        .{ ":gain", Arg{ .default = 1.0, .pos = 2 } },
        .{ ":input", Arg{ .default = null, .pos = 3 } },
    });

    fn linearize(expr: *ast.NodeDataExpression, alloc: std.mem.Allocator) InstructionError!void {
        try genLinearize(argmap)(expr, alloc);
    }
};

pub const MathOperation = enum {
    Log2,
    Log10,
    Logn,

    Atan,
    Sigmoid,

    Exp,
    Exp2,

    Floor,
    Ceil,

    MidiToFreq,
    FreqToMidi,
    DbToAmp,
    AmpToDb,

    fn linearize(expr: *ast.NodeDataExpression, _: std.mem.Allocator) InstructionError!void {
        try genValidate(1)(expr);
    }
};

pub const NoiseOperation = enum {
    White,

    fn linearize(expr: *ast.NodeDataExpression, _: std.mem.Allocator) InstructionError!void {
        try genValidate(0)(expr);
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

    const argmap = std.StaticStringMap(Arg).initComptime(.{
        .{ ":freq", Arg{ .default = null, .pos = 0 } },
        .{ ":phase", Arg{ .default = 0.0, .pos = 1 } },
    });

    fn linearize(expr: *ast.NodeDataExpression, alloc: std.mem.Allocator) InstructionError!void {
        try genLinearize(argmap)(expr, alloc);
    }
};

pub const ShaperOperation = enum {
    Clamp,
    Clip,
    Diode,
    Quantize,

    fn linearize(expr: *ast.NodeDataExpression, _: std.mem.Allocator) InstructionError!void {
        try genValidate(2)(expr);
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

    fn linearize(instr: Instruction, expr: *ast.NodeDataExpression, alloc: std.mem.Allocator) InstructionError!void {
        const active_tag = std.meta.activeTag(instr);

        inline for (std.meta.fields(Instruction)) |field| {
            if (comptime std.mem.eql(u8, field.name, "Value")) {
                if (active_tag == .Value) {
                    return;
                }
            } else if (@field(std.meta.Tag(Instruction), field.name) == active_tag) {
                return field.type.linearize(expr, alloc);
            }
        }

        unreachable;
    }

    pub fn fromExpr(expr: *ast.NodeDataExpression, current_slot: *usize, alloc: std.mem.Allocator) InstructionError!Instruction {
        var instr = InstructionMap.get(expr.op) orelse return InstructionError.NotFound;
        try instr.linearize(expr, alloc);

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
    .{ "<", Instruction{ .Arith = ArithmeticOperation.Lt } },
    .{ "<=", Instruction{ .Arith = ArithmeticOperation.Leq } },
    .{ ">", Instruction{ .Arith = ArithmeticOperation.Gt } },
    .{ ">=", Instruction{ .Arith = ArithmeticOperation.Geq } },

    .{ "highpass", Instruction{ .Filter = FilterOperation{ .t = FilterOperationType.High, .tmp_slot = 0 } } },
    .{ "lowpass", Instruction{ .Filter = FilterOperation{ .t = FilterOperationType.Low, .tmp_slot = 0 } } },

    .{ "log2", Instruction{ .Math = MathOperation.Log2 } },
    .{ "log10", Instruction{ .Math = MathOperation.Log10 } },
    .{ "logn", Instruction{ .Math = MathOperation.Logn } },
    .{ "atan", Instruction{ .Math = MathOperation.Atan } },
    .{ "sigmoid", Instruction{ .Math = MathOperation.Sigmoid } },
    .{ "exp", Instruction{ .Math = MathOperation.Exp } },
    .{ "exp2", Instruction{ .Math = MathOperation.Exp2 } },
    .{ "floor", Instruction{ .Math = MathOperation.Floor } },
    .{ "ceil", Instruction{ .Math = MathOperation.Ceil } },
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
