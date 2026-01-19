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

pub fn expand(state: *CompilerState, tmp: *Node) anyerror!bool {
    var expr = tmp.data.list.items[1];
    for (2..tmp.data.list.items.len) |i| {
        try tmp.data.list.items[i].data.list.insert(state.alloc.ast_alloc, 1, expr);
        expr = tmp.data.list.items[i];
    }
    tmp.data = expr.data;

    return try compiler.compileExpr(state, tmp);
}
