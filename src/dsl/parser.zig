const std = @import("std");

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

pub const NodeType = enum {
    ident,
    value,
    atom,
    expr,
};

pub const Node = struct { text: []const u8, children: std.ArrayList(Node) };
