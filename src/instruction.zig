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

const Validate = fn (*ast.Node) InstructionError!void;
const Linearize = fn (*ast.Node, std.mem.Allocator) InstructionError!void;

fn genValidate(comptime arity: comptime_int) Validate {
    return struct {
        fn validate(node: *ast.Node) InstructionError!void {
            if (node.data.Expr.children.items.len != arity) {
                return InstructionError.BadArity;
            }
        }
    }.validate;
}

fn genLinearize(comptime argmap: anytype) Linearize {
    const arg_count = argmap.keys().len;
    return struct {
        fn linearize(node: *ast.Node, alloc: std.mem.Allocator) InstructionError!void {
            var args: [arg_count]?*ast.Node = .{null} ** arg_count;

            var i: usize = 0;
            while (i < node.data.Expr.children.items.len) {
                const key_node = node.data.Expr.children.items[i];
                switch (key_node.data) {
                    .Atom => {},
                    else => return InstructionError.BadArgument,
                }

                const arg = argmap.get(key_node.data.Atom) orelse return InstructionError.NotFound;
                args[arg.pos] = node.data.Expr.children.items[i + 1];

                i += 2;
            }

            for (argmap.values()) |arg| {
                if (null == args[arg.pos]) {
                    const default = arg.default orelse return InstructionError.MissingArgument;
                    var new_node = alloc.create(ast.Node) catch return InstructionError.MemoryError;
                    new_node.src = "<DEFAULT>";
                    new_node.visited = false;
                    new_node.data = ast.NodeData{ .Value = default };
                    args[arg.pos] = new_node;
                }
            }

            node.data.Expr.children.clearRetainingCapacity();
            for (args) |arg| {
                node.data.Expr.children.append(alloc, arg.?) catch return InstructionError.MemoryError;
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

    fn linearize(node: *ast.Node, _: std.mem.Allocator) InstructionError!void {
        try genValidate(2)(node);
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

    fn linearize(node: *ast.Node, alloc: std.mem.Allocator) InstructionError!void {
        try genLinearize(argmap)(node, alloc);
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

    fn linearize(node: *ast.Node, _: std.mem.Allocator) InstructionError!void {
        try genValidate(1)(node);
    }
};

pub const MixOperation = enum {
    Blend,
    Mixer,

    fn linearize(node: *ast.Node, _: std.mem.Allocator) InstructionError!void {
        try genValidate(3)(node);
    }
};

pub const NoiseOperation = enum {
    White,

    fn linearize(node: *ast.Node, _: std.mem.Allocator) InstructionError!void {
        try genValidate(0)(node);
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

    fn linearize(node: *ast.Node, alloc: std.mem.Allocator) InstructionError!void {
        try genLinearize(argmap)(node, alloc);
    }
};

pub const ShaperOperation = enum {
    Clamp,
    Clip,
    Diode,
    Quantize,

    fn linearize(node: *ast.Node, _: std.mem.Allocator) InstructionError!void {
        try genValidate(2)(node);
    }
};

pub const Instruction = union(enum) {
    Arith: ArithmeticOperation,
    Filter: FilterOperation,
    Math: MathOperation,
    Mix: MixOperation,
    Noise: NoiseOperation,
    Osc: OscOperation,
    Shaper: ShaperOperation,
    Value: f32,

    fn linearize(instr: Instruction, node: *ast.Node, alloc: std.mem.Allocator) InstructionError!void {
        const active_tag = std.meta.activeTag(instr);

        inline for (std.meta.fields(Instruction)) |field| {
            if (comptime std.mem.eql(u8, field.name, "Value")) {
                if (active_tag == .Value) {
                    return;
                }
            } else if (@field(std.meta.Tag(Instruction), field.name) == active_tag) {
                return field.type.linearize(node, alloc);
            }
        }

        unreachable;
    }

    pub fn fromExpr(node: *ast.Node, current_slot: *usize, alloc: std.mem.Allocator) InstructionError!Instruction {
        var instr = InstructionMap.get(node.data.Expr.op) orelse return InstructionError.NotFound;
        try instr.linearize(node, alloc);

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

    .{ "blend", Instruction{ .Mix = MixOperation.Blend } },
    .{ "mixer", Instruction{ .Mix = MixOperation.Mixer } },

    .{ "white-noise", Instruction{ .Noise = NoiseOperation.White } },

    .{ "sawtooth", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sawtooth, .phase_slot = 0 } } },
    .{ "sine", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Sine, .phase_slot = 0 } } },
    .{ "square", Instruction{ .Osc = OscOperation{ .t = OscOperationType.Square, .phase_slot = 0 } } },

    .{ "clamp", Instruction{ .Shaper = ShaperOperation.Clamp } },
    .{ "clip", Instruction{ .Shaper = ShaperOperation.Clip } },
    .{ "diode", Instruction{ .Shaper = ShaperOperation.Diode } },
    .{ "quantize", Instruction{ .Shaper = ShaperOperation.Quantize } },
});
