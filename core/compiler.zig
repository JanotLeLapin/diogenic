const std = @import("std");
const log = std.log.scoped(.compiler);

const engine = @import("engine.zig");

const function = @import("compiler/function.zig");

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

const instruction_compiler = @import("compiler/instruction.zig");
const special = @import("compiler/special.zig");
const Macros = special.Macros;

pub const DiogenicStd = std.StaticStringMap([:0]const u8).initComptime(.{
    .{ "std/builtin", @embedFile("std/builtin.scm") },
});

pub const Constants = std.StaticStringMap(f32).initComptime(.{
    .{ "E", std.math.e },
    .{ "PI", std.math.pi },
    .{ "PHI", std.math.phi },
});

pub const CompilerException = enum {
    unknown_expr,
    unknown_arg,
    unexpected_arg,
    bad_arity,
    bad_expr,
    variable_not_found,
    unresolved_import,
};

pub const CompilerExceptionData = struct {
    node: *Node,
    exception: CompilerException,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{s}: {s}", .{
            @tagName(
                self.exception,
            ),
            self.node.src,
        });
    }
};

pub const CompilerState = struct {
    state_index: usize = 0,
    reg_index: usize = 0,

    env: std.StringHashMap(usize),
    func: std.StringHashMap(*Node),

    instructions: *std.ArrayList(Instruction),
    exceptions: *std.ArrayList(CompilerExceptionData),
    alloc: CompilerAlloc,

    pub fn deinit(self: *CompilerState) void {
        self.env.deinit();
        self.func.deinit();
    }
};

pub const CompilerAlloc = struct {
    /// parser stack allocator
    stack_alloc: std.mem.Allocator,
    /// instructions array list allocator
    instr_alloc: std.mem.Allocator,
    /// errors array list allocator
    exception_alloc: std.mem.Allocator,
    /// ast allocator
    ast_alloc: std.mem.Allocator,
    /// compiler state environment & functions allocator
    env_alloc: std.mem.Allocator,
};

pub fn compileExpr(state: *CompilerState, tmp: *Node) anyerror!bool {
    var failed = false;

    const op = switch (tmp.data) {
        .list => |lst| lst.items[0].data.id,
        .num => |num| {
            try state.instructions.append(
                state.alloc.instr_alloc,
                Instruction{ ._push = instruction.value.Push{ .value = num } },
            );
            return true;
        },
        .id => |id| {
            if (state.env.get(id)) |idx| {
                try state.instructions.append(
                    state.alloc.instr_alloc,
                    Instruction{ ._load = instruction.value.Load{ .reg_index = idx } },
                );
            } else if (Constants.get(id)) |v| {
                try state.instructions.append(
                    state.alloc.instr_alloc,
                    Instruction{ ._push = instruction.value.Push{ .value = v } },
                );
            } else {
                try state.exceptions.append(state.alloc.exception_alloc, .{
                    .node = tmp,
                    .exception = .variable_not_found,
                });
                return false;
            }
            return true;
        },
        else => unreachable,
    };

    if (instruction.getExpressionIndex(op)) |_| {
        if (!try instruction_compiler.expand(state, tmp)) {
            return false;
        }

        for (tmp.data.list.items[1..]) |child| {
            if (!try compileExpr(state, child)) {
                failed = true;
            }
        }

        const instr = try instruction_compiler.compile(tmp);
        try state.instructions.append(state.alloc.instr_alloc, instr);
    } else if (state.func.get(op)) |func| {
        if (!try function.expand(state, tmp, func)) {
            failed = true;
        }
    } else if (Macros.get(op)) |f| {
        if (!try f(state, tmp)) {
            failed = true;
        }
    } else {
        try state.exceptions.append(state.alloc.exception_alloc, .{
            .exception = .unknown_expr,
            .node = tmp,
        });
        failed = true;
    }

    return !failed;
}

pub fn compile(
    root: *Node,
    instructions: *std.ArrayList(Instruction),
    errors: *std.ArrayList(CompilerExceptionData),
    alloc: CompilerAlloc,
) !bool {
    var state = CompilerState{
        .env = std.StringHashMap(usize).init(alloc.env_alloc),
        .func = std.StringHashMap(*Node).init(alloc.env_alloc),
        .instructions = instructions,
        .exceptions = errors,
        .alloc = alloc,
    };
    defer state.deinit();

    var i: usize = 0;
    while (i < root.data.list.items.len) {
        const child = root.data.list.items[i];
        if (std.mem.eql(u8, "use", child.data.list.items[0].data.id)) {
            const src = DiogenicStd.get(child.data.list.items[1].data.id) orelse {
                try errors.append(alloc.exception_alloc, .{
                    .exception = .unresolved_import,
                    .node = child,
                });
                return false;
            };
            var t: Tokenizer = .{ .src = src };
            const ast = try parser.parse(&t, alloc.ast_alloc, alloc.stack_alloc);
            _ = root.data.list.orderedRemove(i);
            try root.data.list.insertSlice(alloc.ast_alloc, i, ast.data.list.items);
            continue;
        } else if (std.mem.eql(u8, "defun", child.data.list.items[0].data.id)) {
            try state.func.put(child.data.list.items[1].data.id, child);
        } else {
            return try compileExpr(
                &state,
                child,
            );
        }
        i += 1;
    }

    return true;
}
