const std = @import("std");

const types = @import("../types.zig");
const State = types.State;

const rpn = @import("../rpn.zig");

const engine = @import("../../engine.zig");

const instr = @import("../../instruction.zig");
const Instr = instr.Instruction;
const Instrs = instr.Instructions;

const parser = @import("../../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub fn expand(state: *State, node: *Node) anyerror!void {
    if (6 != node.data.list.items.len) {
        try state.pushException(.bad_arity, node, null);
        return;
    }

    var failed = false;
    var params: [4]f32 = undefined;
    for (node.data.list.items[2..], 0..) |child, i| {
        switch (child.data) {
            .num => |v| params[i] = v,
            else => {
                try state.pushException(.unexpected_arg, child, "expected num");
                failed = true;
            },
        }
    }

    if (failed) {
        return;
    }

    const a = (params[3] - params[2]) / (params[1] - params[0]);
    const b = params[2] - a * params[0];

    try state.pushInstr(.{ ._push = .{ .value = a } });
    try rpn.expand(state, node.data.list.items[1]);
    try state.pushInstr(.{ .@"*" = .{} });
    try state.pushInstr(.{ ._push = .{ .value = b } });
    try state.pushInstr(.{ .@"+" = .{} });
}
