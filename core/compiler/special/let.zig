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
    const list = switch (node.data) {
        .list => |lst| lst.items,
        else => {
            try state.pushException(.bad_expr, node, "expected list");
            return;
        },
    };

    if (list.len != 3) {
        try state.pushException(.bad_arity, node, null);
        return;
    }

    const bindings = switch (list[1].data) {
        .list => |lst| lst.items,
        else => {
            try state.pushException(.bad_expr, list[1], "expected list");
            return;
        },
    };
    if (0 != (bindings.len % 2)) {
        try state.pushException(.unexpected_arg, bindings[bindings.len - 1], "trailing binding");
        return;
    }

    const body = list[2];

    var i: usize = 0;
    while (i < bindings.len) : (i += 2) {
        const name = switch (bindings[i].data) {
            .id => |id| id,
            else => {
                try state.pushException(.bad_expr, bindings[i], "expected ident");
                return;
            },
        };

        const reg_index = state.reg_index;
        state.reg_index += 1;

        try state.env.put(name, reg_index);
        try rpn.expand(state, bindings[i + 1]);
        try state.pushInstr(Instr{
            ._store = instr.value.Store{ .reg_index = reg_index },
        });
    }

    try rpn.expand(state, body);

    while (i < bindings.len) : (i += 2) {
        const name = bindings[i].data.id;
        _ = state.env.remove(name);
    }
}
