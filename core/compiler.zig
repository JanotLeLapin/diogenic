const std = @import("std");
const log = std.log.scoped(.compiler);

const engine = @import("engine.zig");

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

pub const macro_pass = @import("compiler/macro.zig");
const MacroState = macro_pass.State;

pub const inline_pass = @import("compiler/inline.zig");
const InlineState = inline_pass.State;

pub const alpha_pass = @import("compiler/alpha.zig");
const AlphaState = alpha_pass.State;

pub const optimize_pass = @import("compiler/optimize.zig");

pub const instruction_compiler = @import("compiler/instruction.zig");
pub const special_compiler = @import("compiler/special.zig");
const Specials = special_compiler.Specials;

pub const sourcemap = @import("compiler/sourcemap.zig");

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
};

pub const CompilerState = struct {
    state_index: usize = 0,
    reg_index: usize = 0,

    env: std.StringHashMap(usize),

    instructions: *std.ArrayList(Instruction),
    exceptions: *std.ArrayList(CompilerExceptionData),
    alloc: CompilerAlloc,
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
    /// custom instruction compiler alloc
    custom_instr_alloc: std.mem.Allocator,
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
        else => {
            try state.exceptions.append(state.alloc.exception_alloc, .{
                .exception = .unknown_expr,
                .node = tmp,
            });
            return false;
        },
    };

    if (instruction.getExpressionIndex(op)) |_| {
        if (!try instruction_compiler.expand(state, tmp)) {
            failed = true;
        }

        for (tmp.data.list.items[1..]) |child| {
            if (!try compileExpr(state, child)) {
                failed = true;
            }
        }

        const instr = try instruction_compiler.compile(.{
            .node = tmp,
            .alloc = state.alloc.custom_instr_alloc,
        });
        try state.instructions.append(state.alloc.instr_alloc, instr);
    } else if (Specials.get(op)) |f| {
        if (!try f(state, tmp)) {
            failed = true;
        }
    } else {
        try state.exceptions.append(state.alloc.exception_alloc, .{
            .exception = .unknown_expr,
            .node = tmp.data.list.items[0],
        });
        failed = true;
    }

    return !failed;
}

pub fn compile(
    src: []const u8,
    instructions: *std.ArrayList(Instruction),
    errors: *std.ArrayList(CompilerExceptionData),
    alloc: CompilerAlloc,
) !bool {
    var t = Tokenizer{ .src = src };
    const root = try parser.parse(&t, alloc.ast_alloc, alloc.stack_alloc);

    {
        const macro_state = MacroState{
            .exceptions = errors,
            .ast_alloc = alloc.ast_alloc,
            .exceptions_alloc = alloc.exception_alloc,
        };

        if (!try macro_pass.expand(&macro_state, root)) {
            return false;
        }
    }

    {
        var inline_state = InlineState{
            .exceptions = errors,
            .func = std.StringHashMap(inline_pass.Function).init(alloc.env_alloc),
            .exceptions_alloc = alloc.exception_alloc,
            .func_alloc = alloc.env_alloc,
            .ast_alloc = alloc.ast_alloc,
            .stack_alloc = alloc.stack_alloc,
        };
        defer inline_state.func.deinit();

        if (!try inline_pass.analyze(&inline_state, root)) {
            return false;
        }
    }

    {
        var alpha_state = AlphaState{
            .bindings = std.StringHashMap(
                std.ArrayList([]const u8),
            ).init(alloc.env_alloc),
            .alloc = alloc.env_alloc,
        };
        defer alpha_state.bindings.deinit();

        try alpha_pass.expand(&alpha_state, root);
    }

    try optimize_pass.optimize(alloc.env_alloc, root);

    var state = CompilerState{
        .env = std.StringHashMap(usize).init(alloc.env_alloc),
        .instructions = instructions,
        .exceptions = errors,
        .alloc = alloc,
    };
    defer state.env.deinit();

    return try compileExpr(
        &state,
        root.data.list.items[root.data.list.items.len - 1],
    );
}
