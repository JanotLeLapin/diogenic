const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerError = compiler.CompilerError;
const CompilerState = compiler.CompilerState;

const instruction = @import("../instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub fn expand(
    state: *CompilerState,
    tmp: *Node,
    func: *Node,
) anyerror!bool {
    const args = func.data.list.items[2].data.list.items;
    const expr = func.data.list.items[3];

    if (tmp.data.list.items.len - 1 != args.len) {
        try state.exceptions.append(state.alloc.exception_alloc, .{
            .exception = .bad_arity,
            .node = tmp,
        });
        return false;
    }

    var virtual_state = state.*;
    virtual_state.env = std.StringHashMap(usize).init(state.alloc.env_alloc);
    defer virtual_state.env.deinit();

    for (args, tmp.data.list.items[1..]) |arg, input| {
        try virtual_state.env.put(arg.data.id, virtual_state.reg_index);

        if (!try compiler.compileExpr(state, input)) {
            return false;
        }

        try state.instructions.append(state.alloc.instr_alloc, Instruction{
            ._store = .{ .reg_index = virtual_state.reg_index },
        });
        virtual_state.reg_index += 1;
    }

    if (!try compiler.compileExpr(&virtual_state, expr)) {
        return false;
    }

    for (args) |arg| {
        try state.instructions.append(state.alloc.instr_alloc, Instruction{
            ._free = .{ .reg_index = virtual_state.env.get(arg.data.id).? },
        });
    }

    state.state_index = virtual_state.state_index;
    state.reg_index = virtual_state.reg_index;

    return true;
}
