const std = @import("std");

pub const Tokenizer = struct {
    src: []const u8,
    cursor: usize = 0,

    pub inline fn getChar(self: *const Tokenizer) u8 {
        return self.src[self.cursor];
    }
};

pub const Token = union(enum) {
    sep: u8,
    lit: []const u8,
    whitespace,
};

pub const Node = struct {
    data: union(enum) {
        list: std.ArrayList(*Node),
        id: []const u8,
        num: f32,
    },
    src: []const u8,
};

pub inline fn isWhitespace(c: u8) bool {
    return switch (c) {
        '\n', '\t', ' ' => true,
        else => false,
    };
}

pub fn tokenizerSkipWhitespace(t: *Tokenizer) ?Token {
    if (!isWhitespace(t.getChar())) {
        return null;
    }

    t.cursor += 1;
    while (true) {
        if (t.cursor >= t.src.len) {
            return .whitespace;
        }

        if (!isWhitespace(t.getChar())) {
            return .whitespace;
        }
        t.cursor += 1;
    }
}

pub fn tokenizerNext(t: *Tokenizer) ?Token {
    if (t.cursor >= t.src.len) {
        return null;
    }

    if (tokenizerSkipWhitespace(t)) |token| {
        return token;
    }

    switch (t.getChar()) {
        '(', ')' => {
            const token = Token{ .sep = t.getChar() };
            t.cursor += 1;
            return token;
        },
        else => {},
    }

    const start = t.cursor;
    t.cursor += 1;
    while (true) {
        if (t.cursor >= t.src.len or isWhitespace(t.getChar())) {
            break;
        }

        switch (t.getChar()) {
            '(', ')' => break,
            else => {},
        }

        t.cursor += 1;
    }

    const lit = t.src[start..t.cursor];
    return Token{ .lit = lit };
}

pub fn parse(
    t: *Tokenizer,
    ast_alloc: std.mem.Allocator,
    stack_alloc: std.mem.Allocator,
) !*Node {
    var stack = try std.ArrayList(*Node).initCapacity(stack_alloc, 8);
    defer stack.deinit(stack_alloc);

    const root = try ast_alloc.create(Node);
    root.* = .{
        .data = .{ .list = try std.ArrayList(*Node).initCapacity(ast_alloc, 8) },
        .src = t.src,
    };
    try stack.append(stack_alloc, root);

    while (tokenizerNext(t)) |token| {
        switch (token) {
            .whitespace => continue,
            .sep => |sep| switch (sep) {
                '(' => {
                    const new = try ast_alloc.create(Node);
                    const start = t.cursor - 1;
                    new.* = .{
                        .data = .{ .list = try std.ArrayList(*Node).initCapacity(ast_alloc, 8) },
                        .src = t.src[start..],
                    };
                    try stack.getLast().data.list.append(ast_alloc, new);
                    try stack.append(stack_alloc, new);
                    continue;
                },
                ')' => {
                    var node = stack.pop() orelse return error.EmptyStack;
                    const start = node.src.ptr - t.src.ptr;
                    node.src = t.src[start..t.cursor];
                    continue;
                },
                else => {},
            },
            else => {},
        }

        const new = try ast_alloc.create(Node);
        new.src = token.lit;
        if (std.fmt.parseFloat(f32, token.lit)) |num| {
            new.data = .{ .num = num };
        } else |_| {
            new.data = .{ .id = token.lit };
        }
        try stack.getLast().data.list.append(ast_alloc, new);
    }

    return root;
}
