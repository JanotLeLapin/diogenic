const std = @import("std");

const ast = @import("ast.zig");
const instruction = @import("instruction.zig");

pub fn compile_expr(root: *ast.Node, res_allocator: std.mem.Allocator, stack_allocator: std.mem.Allocator) !std.ArrayList(instruction.Instruction) {
    var res = try std.ArrayList(instruction.Instruction).initCapacity(res_allocator, 64);

    var pre_stack = try std.ArrayList(*ast.Node).initCapacity(stack_allocator, 32);
    defer pre_stack.deinit(stack_allocator);

    var post_stack = try std.ArrayList(*ast.Node).initCapacity(stack_allocator, 32);
    defer post_stack.deinit(stack_allocator);

    try pre_stack.append(stack_allocator, root);

    while (pre_stack.items.len > 0) {
        const tmp = pre_stack.pop().?;
        try post_stack.append(stack_allocator, tmp);

        switch (tmp.data) {
            .Expr => {
                for (tmp.data.Expr.children.items) |child| {
                    try pre_stack.append(stack_allocator, child);
                }
            },
            else => {},
        }
    }

    var current_slot: usize = 0;
    while (post_stack.items.len > 0) {
        const tmp = post_stack.pop().?;

        switch (tmp.data) {
            .Expr => {
                var instr = instruction.Instruction.fromIdent(tmp.data.Expr.op).?;
                switch (instr) {
                    .Osc => {
                        instr.Osc.phase_slot = current_slot;
                        current_slot += 1;
                    },
                    else => {},
                }
                try res.append(res_allocator, instr);
            },
            .Value => {
                const instr = instruction.Instruction{ .Value = tmp.data.Value };
                try res.append(res_allocator, instr);
            },
            else => {},
        }
    }

    return res;
}
