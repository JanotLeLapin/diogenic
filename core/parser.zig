const std = @import("std");

pub const Pos = struct {
    row: usize,
    col: usize,
};

pub const Tokenizer = struct {
    src: []const u8,
    cursor: usize = 0,
    line: usize = 0,
    last_newline: usize = 0,

    pub inline fn getChar(self: *const Tokenizer) u8 {
        return self.src[self.cursor];
    }

    pub inline fn getPos(self: *const Tokenizer) Pos {
        return .{
            .row = self.line,
            .col = self.cursor - self.last_newline,
        };
    }
};

pub const Token = struct {
    pos: Pos,
    tag: union(enum) {
        sep: u8,
        lit: []const u8,
        whitespace,
        comment,
    },
};

pub const Node = struct {
    data: union(enum) {
        list: std.ArrayList(*Node),
        id: []const u8,
        atom: []const u8,
        num: f32,
    },
    src: []const u8,
    pos: Pos,
};

pub inline fn isWhitespace(c: u8) u8 {
    return switch (c) {
        '\n' => 1,
        '\t', ' ' => 2,
        else => 0,
    };
}

pub fn tokenizerSkipWhitespace(t: *Tokenizer) ?Token {
    const start_pos = t.getPos();

    if (t.cursor >= t.src.len or isWhitespace(t.getChar()) == 0) {
        return null;
    }

    while (t.cursor < t.src.len) {
        switch (isWhitespace(t.getChar())) {
            0 => break,
            1 => {
                t.line += 1;
                t.last_newline = t.cursor + 1;
            },
            else => {},
        }
        t.cursor += 1;
    }

    return .{
        .pos = start_pos,
        .tag = .whitespace,
    };
}

pub fn tokenizerNext(t: *Tokenizer) ?Token {
    if (t.cursor >= t.src.len) {
        return null;
    }

    if (tokenizerSkipWhitespace(t)) |token| {
        return token;
    }

    const start_pos = t.getPos();

    switch (t.getChar()) {
        '(', ')' => {
            const token = Token{
                .pos = start_pos,
                .tag = .{ .sep = t.getChar() },
            };
            t.cursor += 1;
            return token;
        },
        ';' => {
            while (true) {
                if (t.cursor >= t.src.len or t.src[t.cursor] == '\n') {
                    _ = tokenizerSkipWhitespace(t);
                    return .{
                        .pos = start_pos,
                        .tag = .comment,
                    };
                }
                t.cursor += 1;
            }
        },
        else => {},
    }

    const start = t.cursor;
    t.cursor += 1;
    while (true) {
        if (t.cursor >= t.src.len or isWhitespace(t.getChar()) > 0) {
            break;
        }

        switch (t.getChar()) {
            '(', ')' => break,
            else => {},
        }

        t.cursor += 1;
    }

    const lit = t.src[start..t.cursor];
    return .{
        .pos = start_pos,
        .tag = .{ .lit = lit },
    };
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
        .pos = .{ .col = 0, .row = 0 },
    };
    try stack.append(stack_alloc, root);

    while (tokenizerNext(t)) |token| {
        switch (token.tag) {
            .whitespace, .comment => continue,
            .sep => |sep| switch (sep) {
                '(' => {
                    const new = try ast_alloc.create(Node);
                    const start = t.cursor - 1;
                    new.* = .{
                        .data = .{ .list = try std.ArrayList(*Node).initCapacity(ast_alloc, 8) },
                        .src = t.src[start..],
                        .pos = token.pos,
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
        new.src = token.tag.lit;
        new.pos = token.pos;
        if (token.tag.lit[0] == ':') {
            new.data = .{ .atom = token.tag.lit };
        } else if (std.fmt.parseFloat(f32, token.tag.lit)) |num| {
            new.data = .{ .num = num };
        } else |_| {
            new.data = .{ .id = token.tag.lit };
        }
        try stack.getLast().data.list.append(ast_alloc, new);
    }

    return root;
}
