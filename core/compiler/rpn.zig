const std = @import("std");

const util = @import("util.zig");

const types = @import("types.zig");
const Function = types.Function;
const State = types.State;

const engine = @import("../engine.zig");
const CompileData = engine.CompileData;

const instr = @import("../instruction.zig");
const Instr = instr.Instruction;
const Instrs = instr.Instructions;

const Specials = @import("special.zig").Specials;

const parser = @import("../parser.zig");
const Node = parser.Node;

const Constants = std.StaticStringMap(f32).initComptime(.{
    .{ "E", std.math.e },
    .{ "PI", std.math.pi },
    .{ "PHI", std.math.phi },
    .{ "INF", std.math.inf(f32) },
});

fn compileExpr(d: CompileData, comptime T: type) anyerror!Instr {
    return @unionInit(Instr, T.name, try T.compile(d));
}

pub fn expand(state: *State, node: *Node) anyerror!void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        .num => |num| {
            try state.pushInstr(Instr{
                ._push = instr.value.Push{ .value = num },
            });
            return;
        },
        .id => |id| {
            if (state.env.get(id)) |reg| {
                try state.pushInstr(Instr{
                    ._load = instr.value.Load{ .reg_index = reg },
                });
            } else if (Constants.get(id)) |v| {
                try state.pushInstr(.{
                    ._push = instr.value.Push{ .value = v },
                });
            } else {
                try state.pushException(.unresolved_symbol, node, "unknown expression");
            }
            return;
        },
        else => {
            try state.pushException(.unresolved_symbol, node, "unknown expression");
            return;
        },
    };

    if (1 > expr.len) {
        try state.pushException(.bad_expr, node, "empty expression");
        return;
    }

    const op = switch (expr[0].data) {
        .id => |id| id,
        else => {
            try state.pushException(.unexpected_arg, expr[0], "expected ident");
            return;
        },
    };

    if (instr.getExpressionIndex(op)) |idx| {
        switch (idx) {
            inline 5...Instrs.len - 1 => |i| {
                const T = Instrs[i];

                var f = try Function.fromInstruction(state.stack_alloc, T);
                defer f.deinit(state.stack_alloc);

                try util.reorderArgs(state, node, &f);

                for (node.data.list.items[1..]) |child| {
                    try expand(state, child);
                }

                const d: CompileData = .{
                    .alloc = state.instr_alloc,
                    .node = node,
                };

                const instruction = try compileExpr(d, T);
                try state.pushInstr(instruction);
            },
            else => unreachable,
        }
    } else if (Specials.get(op)) |hook| {
        try hook(state, node);
    } else {
        try state.pushException(.unknown_expr, expr[0], null);
        return;
    }
}
