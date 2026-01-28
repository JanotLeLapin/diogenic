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
    if (node.data.list.items.len != 3) {
        // FIXME: bad arity
        return;
    }

    const bindings = switch (node.data.list.items[1].data) {
        .list => |lst| lst,
        else => {
            // FIXME: expected list
            return;
        },
    };
    const body = node.data.list.items[2];

    var i: usize = 0;
    while (i < bindings.items.len) : (i += 2) {
        const name = bindings.items[i].data.id;
        const reg_index = state.reg_index;
        state.reg_index += 1;

        try state.env.put(name, reg_index);
        try rpn.expand(state, bindings.items[i + 1]);
        try state.pushInstr(Instr{
            ._store = instr.value.Store{ .reg_index = reg_index },
        });
    }

    try rpn.expand(state, body);

    while (i < bindings.items.len) : (i += 2) {
        const name = bindings.items[i].data.id;
        _ = state.env.remove(name);
    }
}
