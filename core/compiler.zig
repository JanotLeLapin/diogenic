const std = @import("std");
const log = std.log.scoped(.compiler);

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;

pub fn compile(root: *Node, alloc: std.mem.Allocator) !std.ArrayList(Instruction) {
    var pre_stack = try std.ArrayList(*Node).initCapacity(alloc, 32);
    defer pre_stack.deinit(alloc);

    var post_stack = try std.ArrayList(Instruction).initCapacity(alloc, 32);
    defer post_stack.deinit(alloc);

    try pre_stack.append(alloc, root);

    var has_error = false;
    while (pre_stack.items.len > 0) {
        const tmp = pre_stack.pop().?;
        if (instruction.compile(tmp)) |instr| {
            try post_stack.append(alloc, instr);
        } else |err| {
            has_error = true;
            log.err("{s}: could not compile '{s}'", .{ @errorName(err), tmp.src });
            continue;
        }

        const children = switch (tmp.data) {
            .list => |lst| lst,
            else => continue,
        };

        for (children.items) |child| {
            switch (child.data) {
                .id => continue,
                else => {},
            }

            try pre_stack.append(alloc, child);
        }
    }

    if (has_error) {
        return error.CompilationError;
    }

    var res = try std.ArrayList(Instruction).initCapacity(alloc, 64);
    while (post_stack.pop()) |tmp| {
        try res.append(alloc, tmp);
    }

    return res;
}
