const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerError = compiler.CompilerError;
const CompilerState = compiler.CompilerState;

const engine = @import("../engine.zig");

const instruction = @import("../instruction.zig");
const Instruction = instruction.Instruction;
const Instructions = instruction.Instructions;

const parser = @import("../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub fn expand(state: *CompilerState, tmp: *Node) anyerror!bool {
    const bindings = tmp.data.list.items[1].data.list;
    const expr = tmp.data.list.items[2];

    var i: usize = 0;
    while (i < bindings.items.len) {
        const name = bindings.items[i].data.id;
        const reg_index = state.reg_index;
        state.reg_index += 1;

        try state.env.put(name, reg_index);
        if (!try compiler.compileExpr(state, bindings.items[i + 1])) {
            return false;
        }

        try state.instructions.append(state.alloc.instr_alloc, Instruction{
            ._store = instruction.value.Store{ .reg_index = reg_index },
        });

        i += 2;
    }

    if (!try compiler.compileExpr(state, expr)) {
        return false;
    }

    i = 0;
    while (i < bindings.items.len) {
        const name = bindings.items[i].data.id;
        const reg_index = state.reg_index;
        state.reg_index += 1;

        _ = state.env.remove(name);
        try state.instructions.append(state.alloc.instr_alloc, Instruction{
            ._free = instruction.value.Free{ .reg_index = reg_index },
        });

        i += 2;
    }

    return true;
}
