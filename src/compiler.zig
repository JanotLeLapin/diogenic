const std = @import("std");

const ast = @import("ast.zig");
const instruction = @import("instruction.zig");

pub fn compileExpr(root: *ast.Node, res_allocator: std.mem.Allocator, stack_allocator: std.mem.Allocator) !std.ArrayList(instruction.Instruction) {
    var res = try std.ArrayList(instruction.Instruction).initCapacity(res_allocator, 64);

    var pre_stack = try std.ArrayList(*ast.Node).initCapacity(stack_allocator, 32);
    defer pre_stack.deinit(stack_allocator);

    var post_stack = try std.ArrayList(instruction.Instruction).initCapacity(stack_allocator, 32);
    defer post_stack.deinit(stack_allocator);

    try pre_stack.append(stack_allocator, root);

    var current_slot: usize = 0;
    var has_error = false;
    while (pre_stack.items.len > 0) {
        var tmp = pre_stack.pop().?;

        switch (tmp.data) {
            .Expr => {
                compile: {
                    const instr = instruction.Instruction.fromExpr(&tmp.data.Expr, &current_slot, res_allocator) catch |err| {
                        std.log.err("{s}: could not compile expr: '{s}'", .{ @errorName(err), tmp.src });
                        has_error = true;
                        break :compile;
                    };
                    try post_stack.append(stack_allocator, instr);
                }

                for (tmp.data.Expr.children.items) |child| {
                    try pre_stack.append(stack_allocator, child);
                }
            },
            .Value => {
                const instr = instruction.Instruction{ .Value = tmp.data.Value };
                try post_stack.append(stack_allocator, instr);
            },
            else => {},
        }
    }

    if (has_error) {
        try res.append(res_allocator, instruction.Instruction{ .Value = 0.0 });
        std.log.err("some errors occured during compilation", .{});
    } else {
        while (post_stack.items.len > 0) {
            const tmp = post_stack.pop().?;
            try res.append(res_allocator, tmp);
        }
    }

    return res;
}
