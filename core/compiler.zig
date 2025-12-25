const std = @import("std");
const log = std.log.scoped(.compiler);

const builtin = @import("builtin");

const engine = @import("engine.zig");

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;

const is_freestanding = builtin.target.os.tag == .freestanding;

pub const Constants = std.StaticStringMap(f32).initComptime(.{
    .{ "E", std.math.e },
    .{ "PI", std.math.pi },
    .{ "PHI", std.math.phi },
});

pub const CompilerState = struct {
    state_index: usize = 0,
    reg_index: usize = 0,

    env: std.StringHashMap(usize),
    func: std.StringHashMap(*Node),

    pub fn deinit(self: *CompilerState) void {
        self.env.deinit();
        self.func.deinit();
    }
};

pub fn compileExpr(
    state: *CompilerState,
    tmp: *Node,
    instructions: *std.ArrayList(Instruction),
    stack_alloc: std.mem.Allocator,
    ast_alloc: std.mem.Allocator,
) !void {
    const op = switch (tmp.data) {
        .list => |lst| lst.items[0].data.id,
        .num => |num| {
            try instructions.append(
                stack_alloc,
                Instruction{ .push = instruction.value.Push{ .value = num } },
            );
            return;
        },
        .id => |id| {
            if (state.env.get(id)) |idx| {
                try instructions.append(
                    stack_alloc,
                    Instruction{ .load = instruction.value.Load{ .reg_index = idx } },
                );
            } else if (Constants.get(id)) |v| {
                try instructions.append(
                    stack_alloc,
                    Instruction{ .push = instruction.value.Push{ .value = v } },
                );
            } else {
                if (!is_freestanding) {
                    log.err("VariableNotFound: could not resolve '{s}'", .{tmp.src});
                }
                return error.VariableNotFound;
            }
            return;
        },
        else => unreachable,
    };

    if (instruction.getExpressionIndex(op)) |_| {
        instruction.expand(tmp, ast_alloc) catch |err| {
            if (!is_freestanding) {
                log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
            }
            return err;
        };

        for (tmp.data.list.items[1..]) |child| {
            try compileExpr(state, child, instructions, stack_alloc, ast_alloc);
        }

        if (instruction.compile(tmp)) |instr| {
            try instructions.append(stack_alloc, instr);
        } else |err| {
            if (!is_freestanding) {
                log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
            }
            return err;
        }
    } else if (std.mem.eql(u8, "let", op)) {
        const bindings = tmp.data.list.items[1].data.list;
        const expr = tmp.data.list.items[2];

        var i: usize = 0;
        while (i < bindings.items.len) {
            const name = bindings.items[i].data.id;
            const reg_index = state.reg_index;
            state.reg_index += 1;

            try state.env.put(name, reg_index);
            try compileExpr(state, bindings.items[i + 1], instructions, stack_alloc, ast_alloc);
            try instructions.append(stack_alloc, Instruction{
                .store = instruction.value.Store{ .reg_index = reg_index },
            });

            i += 2;
        }

        try compileExpr(state, expr, instructions, stack_alloc, ast_alloc);

        i = 0;
        while (i < bindings.items.len) {
            const name = bindings.items[i].data.id;
            const reg_index = state.reg_index;
            state.reg_index += 1;

            _ = state.env.remove(name);
            try instructions.append(stack_alloc, Instruction{
                .free = instruction.value.Free{ .reg_index = reg_index },
            });

            i += 2;
        }
    } else {
        if (!is_freestanding) {
            log.err("UnknownExpression: could not compile '{s}'", .{tmp.src});
        }
        return error.UnknownExpression;
    }
}

pub fn compile(
    root: *Node,
    instructions: *std.ArrayList(Instruction),
    stack_alloc: std.mem.Allocator,
    ast_alloc: std.mem.Allocator,
    func_alloc: std.mem.Allocator,
) !void {
    var state = CompilerState{
        .env = std.StringHashMap(usize).init(stack_alloc),
        .func = std.StringHashMap(*Node).init(func_alloc),
    };
    defer state.deinit();

    for (root.data.list.items) |child| {
        if (std.mem.eql(u8, "defun", child.data.list.items[0].data.id)) {
            try state.func.put(child.data.list.items[1].data.id, child);
        } else {
            try compileExpr(
                &state,
                child,
                instructions,
                stack_alloc,
                ast_alloc,
            );
            return;
        }
    }
}
