const std = @import("std");

const types = @import("types.zig");
const State = types.State;

const parser = @import("../parser.zig");
const Node = parser.Node;

const engine = @import("../engine.zig");
const Block = engine.Block;
const EngineState = engine.EngineState;
const CompileData = engine.CompileData;
const EvalData = engine.EvalData;

const instruction = @import("../instruction.zig");
const Instr = instruction.Instruction;
const Instrs = instruction.Instructions;

pub fn canOptimizeExpr(expr: []const *Node) bool {
    if (0 > expr.len) {
        return false;
    }

    const id = switch (expr[0].data) {
        .id => |id| id,
        else => return false,
    };

    // right now whether the operation ends with
    // '!' is our way to determine whether the
    // associated expression is impure or not
    if ('!' == id[id.len - 1]) {
        return false;
    }

    for (expr[1..]) |child| {
        switch (child.data) {
            .num => {},
            else => return false,
        }
    }

    return true;
}

pub fn preEvaluate(state: *State, expr: []*Node, comptime T: type) !f32 {
    _ = state;

    // this might be dangerous, we're assuming that
    // pure nodes don't depend on compile data
    var instr = try T.compile(undefined);

    var inputs: [@max(T.args.len, 1)]Block = undefined;

    for (expr[1..], 0..) |child, i| {
        inputs[i] = Block.initValue(child.data.num);
    }

    const d: EvalData = .{
        .sample_rate = 44100.0,
        .inputs = &inputs,
        .output = &inputs[0],
        .state = undefined,
        .registry = undefined,
    };

    instr.eval(d);

    return inputs[0].get(0, 0);
}

pub fn fold(state: *State, node: *Node) !void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return,
    };

    if (0 > expr.len) {
        return false;
    }

    const id = switch (expr[0].data) {
        .id => |id| id,
        else => return,
    };

    const expr_idx = instruction.getExpressionIndex(id) orelse return;
    switch (expr_idx) {
        inline 5...(Instrs.len - 1) => |i| {
            const T = Instrs[i];
            const v = try preEvaluate(state, expr, T);

            node.data = .{ .num = v };
        },
        else => return,
    }
}

pub fn expand(state: *State, node: *Node) anyerror!void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return,
    };

    for (expr) |child| {
        try expand(state, child);
    }

    if (canOptimizeExpr(expr)) {
        try fold(state, node);
    }
}
