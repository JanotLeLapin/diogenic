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
