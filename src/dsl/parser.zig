const std = @import("std");

const types = @import("types.zig");

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\n' => true,
        else => false,
    };
}

pub const Tokenizer = struct {
    src: []const u8,
    idx: usize = 0,

    pub fn next(self: *Tokenizer) ?[]const u8 {
        if (self.idx >= self.src.len) {
            return null;
        }

        if (isWhitespace(self.src[self.idx])) {
            self.idx += 1;
            while (isWhitespace(self.src[self.idx])) {
                self.idx += 1;
                continue;
            }
        }

        switch (self.src[self.idx]) {
            '(', ')' => {
                const c = self.src[self.idx..(self.idx + 1)];
                self.idx += 1;
                return c;
            },
            else => {
                const start = self.idx;
                while (!isWhitespace(self.src[self.idx]) and '(' != self.src[self.idx] and ')' != self.src[self.idx]) {
                    self.idx += 1;
                }
                return self.src[start..self.idx];
            },
        }
    }
};

pub fn parse(ast_allocator: std.mem.Allocator, stack_allocator: std.mem.Allocator, tokenizer: *Tokenizer) !*types.Node {
    var stack = try std.ArrayList(*types.Node).initCapacity(stack_allocator, 8);
    defer stack.deinit(stack_allocator);

    const root = try ast_allocator.create(types.Node);
    root.* = .{
        .List = try std.ArrayList(*types.Node).initCapacity(ast_allocator, 4),
    };
    try stack.append(stack_allocator, root);

    while (tokenizer.next()) |token| {
        if (std.mem.eql(u8, "(", token)) {
            const new = try ast_allocator.create(types.Node);
            new.* = .{ .List = try std.ArrayList(*types.Node).initCapacity(ast_allocator, 8) };
            try stack.getLast().List.append(ast_allocator, new);
            try stack.append(stack_allocator, new);
        } else if (std.mem.eql(u8, ")", token)) {
            _ = stack.pop();
        } else {
            const new = try ast_allocator.create(types.Node);
            new.* = .{ .Symbol = token };
            try stack.getLast().List.append(ast_allocator, new);
        }
    }

    return root;
}
