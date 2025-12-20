const std = @import("std");

const engine = @import("engine.zig");
const CompilerState = engine.CompilerState;

const parser = @import("parser.zig");
const Node = parser.Node;

pub const value = @import("instruction/value.zig");
pub const arith = @import("instruction/arith.zig");
pub const math = @import("instruction/math.zig");
pub const noise = @import("instruction/noise.zig");
pub const osc = @import("instruction/osc.zig");
pub const shaper = @import("instruction/shaper.zig");

pub const biquad = @import("instruction/filter/biquad.zig");

pub const Instructions = .{
    value.Push,
    value.Pop,
    value.Store,
    value.Load,
    value.Free,

    arith.Add,
    arith.Sub,
    arith.Mul,
    arith.Div,
    arith.Lt,
    arith.Leq,
    arith.Gt,
    arith.Geq,

    osc.Sine,
    osc.Sawtooth,
    osc.Square,

    math.Log2,
    math.Log10,
    math.Logn,
    math.Exp,
    math.Exp2,
    math.Atan,
    math.Sigmoid,
    math.Floor,
    math.Ceil,
    math.MidiToFreq,
    math.FreqToMidi,
    math.DbToAmp,
    math.AmpToDb,

    noise.Noise,

    shaper.Clamp,
    shaper.Clip,
    shaper.Diode,
    shaper.Foldback,
    shaper.Quantize,

    biquad.High,
    biquad.Low,
    biquad.Band,
    biquad.Notch,
};

pub const Instruction = blk: {
    var union_fields: [Instructions.len]std.builtin.Type.UnionField = undefined;
    var enum_fields: [Instructions.len]std.builtin.Type.EnumField = undefined;

    for (Instructions, 0..) |T, i| {
        union_fields[i] = .{
            .name = T.name,
            .type = T,
            .alignment = @alignOf(T),
        };
        enum_fields[i] = .{
            .name = T.name,
            .value = i,
        };
    }

    break :blk @Type(.{ .@"union" = .{
        .fields = &union_fields,
        .decls = &.{},
        .layout = .auto,
        .tag_type = @Type(.{ .@"enum" = .{
            .tag_type = u32,
            .decls = &.{},
            .fields = &enum_fields,
            .is_exhaustive = true,
        } }),
    } });
};

pub fn getExpressionIndex(name: []const u8) ?usize {
    inline for (Instructions, 0..) |T, i| {
        if (std.mem.eql(u8, name, T.name)) {
            return i;
        }
    }
    return null;
}

pub fn compile(state: *CompilerState, node: *Node) !Instruction {
    const expr = switch (node.data) {
        .list => |lst| lst,
        else => return error.BadExpr,
    };

    const id = switch (expr.items[0].data) {
        .id => |id| id,
        else => return error.BadExpr,
    };

    const i = getExpressionIndex(id) orelse return error.UnknownExpr;

    switch (i) {
        inline 0...Instructions.len - 1 => |ci| {
            return @unionInit(
                Instruction,
                Instructions[ci].name,
                try Instructions[ci].compile(state, node),
            );
        },
        else => unreachable,
    }
}
