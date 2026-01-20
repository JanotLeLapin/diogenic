const std = @import("std");

const compiler = @import("../../compiler.zig");
const CompilerError = compiler.CompilerError;
const CompilerState = compiler.CompilerState;

const engine = @import("../../engine.zig");

const instruction = @import("../../instruction.zig");
const Instruction = instruction.Instruction;
const Instructions = instruction.Instructions;

const parser = @import("../../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub fn expand(state: *CompilerState, node: *Node) anyerror!bool {
    if (6 != node.data.list.items.len) {
        try state.exceptions.append(state.alloc.exception_alloc, .{
            .exception = .bad_arity,
            .node = node,
        });
        return false;
    }

    var failed = false;
    var params: [4]f32 = undefined;
    for (node.data.list.items[2..], 0..) |child, i| {
        switch (child.data) {
            .num => |v| params[i] = v,
            else => {
                try state.exceptions.append(state.alloc.exception_alloc, .{
                    .exception = .unexpected_arg,
                    .node = child,
                });
                failed = true;
            },
        }
    }

    if (failed) {
        return false;
    }

    const a = (params[3] - params[2]) / (params[1] - params[0]);
    const b = params[2] - a * params[0];

    try state.instructions.append(state.alloc.instr_alloc, .{
        ._push = .{ .value = a },
    });
    if (!try compiler.compileExpr(state, node.data.list.items[1])) {
        return false;
    }
    try state.instructions.append(state.alloc.instr_alloc, .{
        .@"*" = .{},
    });
    try state.instructions.append(state.alloc.instr_alloc, .{
        ._push = .{ .value = b },
    });
    try state.instructions.append(state.alloc.instr_alloc, .{
        .@"+" = .{},
    });

    return true;
}
