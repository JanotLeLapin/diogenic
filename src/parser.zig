const std = @import("std");

const ast = @import("ast.zig");

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

pub fn parse(ast_allocator: std.mem.Allocator, stack_allocator: std.mem.Allocator, tokenizer: *Tokenizer) !*ast.Node {
    var stack = try std.ArrayList(*ast.Node).initCapacity(stack_allocator, 8);
    defer stack.deinit(stack_allocator);

    const root = try ast_allocator.create(ast.Node);
    root.* = .{
        .visited = false,
        .data = .{ .Expr = ast.NodeDataExpression{
            .op = "ROOT",
            .children = try std.ArrayList(*ast.Node).initCapacity(ast_allocator, 4),
        } },
        .src = tokenizer.src,
    };
    try stack.append(stack_allocator, root);

    while (tokenizer.next()) |token| {
        if (std.mem.eql(u8, "(", token)) {
            const new = try ast_allocator.create(ast.Node);
            const start = tokenizer.idx - 1;
            new.* = .{
                .visited = false,
                .data = .{ .Expr = ast.NodeDataExpression{
                    .op = tokenizer.next().?,
                    .children = try std.ArrayList(*ast.Node).initCapacity(ast_allocator, 8),
                } },
                .src = tokenizer.src[start..],
            };
            try stack.getLast().data.Expr.children.append(ast_allocator, new);
            try stack.append(stack_allocator, new);
        } else if (std.mem.eql(u8, ")", token)) {
            var node = stack.pop().?;
            const start = node.src.ptr - tokenizer.src.ptr;
            node.src = tokenizer.src[start..tokenizer.idx];
        } else {
            const new = try ast_allocator.create(ast.Node);
            if (std.fmt.parseFloat(f32, token)) |value| {
                new.* = .{
                    .visited = false,
                    .data = .{ .Value = value },
                    .src = token,
                };
            } else |_| {
                if (token[0] == ':') {
                    new.* = .{
                        .visited = false,
                        .data = .{ .Atom = token },
                        .src = token,
                    };
                } else {
                    new.* = .{
                        .visited = false,
                        .data = .{ .Ident = token },
                        .src = token,
                    };
                }
            }
            try stack.getLast().data.Expr.children.append(ast_allocator, new);
        }
    }

    return root;
}
