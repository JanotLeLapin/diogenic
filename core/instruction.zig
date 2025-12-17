const std = @import("std");

const compiler = @import("compiler.zig");
const CompilerState = compiler.CompilerState;

const parser = @import("parser.zig");
const Node = parser.Node;

const value = @import("instruction/value.zig");
const arith = @import("instruction/arith.zig");
const math = @import("instruction/math.zig");
const osc = @import("instruction/osc.zig");
const shaper = @import("instruction/shaper.zig");

const biquad = @import("instruction/filter/biquad.zig");

pub const Instructions = .{
    value.Value,

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
    math.Atan,
    math.Sigmoid,
    math.Floor,
    math.Ceil,
    math.MidiToFreq,
    math.FreqToMidi,
    math.DbToAmp,
    math.AmpToDb,

    shaper.Clamp,
    shaper.Clip,
    shaper.Diode,
    shaper.Quantize,

    biquad.High,
    biquad.Low,
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

pub fn compile(state: *CompilerState, node: *Node) !Instruction {
    const expr = switch (node.data) {
        .list => |lst| lst,
        .num => {
            return Instruction{
                .value = try value.Value.compile(state, node),
            };
        },
        else => return error.BadExpr,
    };

    const id = switch (expr.items[0].data) {
        .id => |id| id,
        else => return error.BadExpr,
    };

    const i = blk: {
        inline for (Instructions, 0..) |T, i| {
            if (std.mem.eql(u8, id, T.name)) {
                break :blk i;
            }
        }
        return error.UnknownExpr;
    };

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
