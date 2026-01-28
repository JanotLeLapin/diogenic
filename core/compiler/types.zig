const std = @import("std");

const instr = @import("../instruction.zig");
const Instr = instr.Instruction;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Argument = struct {
    id_node: *Node,
    doc: ?[]const u8,
};

pub const ArgumentMap = std.StringHashMap(Argument);

pub const Function = struct {
    body: *Node,
    args: std.ArrayList([]const u8),
    arg_map: ArgumentMap,
    doc: ?[]const u8,
};

pub const FunctionMap = std.StringHashMap(Function);

pub const Module = struct {
    root: *Node,
    imports: std.ArrayList(*Module),
    functions: FunctionMap,

    pub fn getFunction(self: *const Module, fn_name: []const u8) ?Function {
        if (self.functions.get(fn_name)) |func| {
            return func;
        }

        for (self.imports.items) |import| {
            if (import.getFunction(fn_name)) |func| {
                return func;
            }
        }

        return null;
    }
};

pub const ModuleMap = std.StringHashMap(*Module);

pub const State = struct {
    map: *ModuleMap,
    instr_seq: *std.ArrayList(Instr),
    env: *std.StringHashMap(usize),
    arena_alloc: std.mem.Allocator,
    stack_alloc: std.mem.Allocator,

    pub fn pushInstr(self: *State, instruction: Instr) !void {
        try self.instr_seq.append(self.stack_alloc, instruction);
    }
};
