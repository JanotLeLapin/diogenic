const std = @import("std");

const instr = @import("../instruction.zig");
const Instr = instr.Instruction;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const SourceMap = struct {
    source: []const u8,
    line_starts: std.ArrayList(usize),

    pub fn init(
        source: []const u8,
        alloc: std.mem.Allocator,
    ) !SourceMap {
        var starts = try std.ArrayList(usize).initCapacity(alloc, source.len / 32);
        try starts.append(alloc, 0);

        for (source, 0..) |c, i| {
            if (c == '\n') {
                try starts.append(alloc, i + 1);
            }
        }
        return SourceMap{
            .source = source,
            .line_starts = starts,
        };
    }

    pub fn deinit(self: *SourceMap, alloc: std.mem.Allocator) void {
        self.line_starts.deinit(alloc);
    }

    pub fn getLine(self: SourceMap, line_idx: usize) ?[]const u8 {
        if (line_idx >= self.line_starts.items.len) return null;

        const start = self.line_starts.items[line_idx];
        const end = if (line_idx + 1 < self.line_starts.items.len)
            self.line_starts.items[line_idx + 1]
        else
            self.source.len;

        var line = self.source[start..end];
        if (std.mem.endsWith(u8, line, "\n")) line = line[0 .. line.len - 1];
        if (std.mem.endsWith(u8, line, "\r")) line = line[0 .. line.len - 1];
        return line;
    }
};

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
    sourcemap: SourceMap,

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
    reg_index: usize = 0,
    arena_alloc: std.mem.Allocator,
    stack_alloc: std.mem.Allocator,

    pub fn pushInstr(self: *State, instruction: Instr) !void {
        try self.instr_seq.append(self.stack_alloc, instruction);
    }
};
