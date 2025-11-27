const std = @import("std");

const ast = @import("ast.zig");
const instruction = @import("instruction.zig");

pub const CompilerAlloc = struct {
    instr_alloc: std.mem.Allocator,
    temp_stack_alloc: std.mem.Allocator,
};

pub fn compileExpr(root: *ast.Node, alloc: CompilerAlloc) !std.ArrayList(instruction.Instruction) {
    var res = try std.ArrayList(instruction.Instruction).initCapacity(alloc.instr_alloc, 64);

    var pre_stack = try std.ArrayList(*ast.Node).initCapacity(alloc.temp_stack_alloc, 32);
    defer pre_stack.deinit(alloc.temp_stack_alloc);

    var post_stack = try std.ArrayList(instruction.Instruction).initCapacity(alloc.temp_stack_alloc, 32);
    defer post_stack.deinit(alloc.temp_stack_alloc);

    try pre_stack.append(alloc.temp_stack_alloc, root);

    var current_slot: usize = 0;
    var has_error = false;
    while (pre_stack.items.len > 0) {
        const tmp = pre_stack.pop().?;

        switch (tmp.data) {
            .Expr => {
                compile: {
                    const instr = instruction.Instruction.fromExpr(tmp, &current_slot, alloc.instr_alloc) catch |err| {
                        std.log.err("{s}: could not compile expr: '{s}'", .{ @errorName(err), tmp.src });
                        has_error = true;
                        break :compile;
                    };
                    try post_stack.append(alloc.temp_stack_alloc, instr);
                }

                for (tmp.data.Expr.children.items) |child| {
                    try pre_stack.append(alloc.temp_stack_alloc, child);
                }
            },
            .Value => {
                const instr = instruction.Instruction{ .Value = tmp.data.Value };
                try post_stack.append(alloc.temp_stack_alloc, instr);
            },
            else => {},
        }
    }

    if (has_error) {
        try res.append(alloc.instr_alloc, instruction.Instruction{ .Value = 0.0 });
        std.log.err("some errors occured during compilation", .{});
    } else {
        while (post_stack.items.len > 0) {
            const tmp = post_stack.pop().?;
            try res.append(alloc.instr_alloc, tmp);
        }
    }

    return res;
}
