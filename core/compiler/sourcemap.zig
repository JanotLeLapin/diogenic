const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerExceptionData = compiler.CompilerExceptionData;

pub const SourceMap = struct {
    source: []const u8,
    line_starts: std.ArrayList(usize),
    alloc: std.mem.Allocator,

    pub fn init(
        alloc: std.mem.Allocator,
        source: []const u8,
    ) !SourceMap {
        var starts = try std.ArrayList(usize).initCapacity(alloc, source.len / 32);
        try starts.append(alloc, 0);

        for (source, 0..) |c, i| {
            if (c == '\n') {
                try starts.append(alloc, i + 1);
            }
        }
        return SourceMap{
            .source = source,
            .line_starts = starts,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *SourceMap) void {
        self.line_starts.deinit(self.alloc);
    }

    pub fn getLine(self: SourceMap, line_idx: usize) ?[]const u8 {
        if (line_idx >= self.line_starts.items.len) return null;

        const start = self.line_starts.items[line_idx];
        const end = if (line_idx + 1 < self.line_starts.items.len)
            self.line_starts.items[line_idx + 1]
        else
            self.source.len;

        var line = self.source[start..end];
        if (std.mem.endsWith(u8, line, "\n")) line = line[0 .. line.len - 1];
        if (std.mem.endsWith(u8, line, "\r")) line = line[0 .. line.len - 1];
        return line;
    }
};

pub fn printExceptionContext(
    map: SourceMap,
    exception: CompilerExceptionData,
    writer: anytype,
) !void {
    const row = exception.node.pos.row;
    const col = exception.node.pos.col;

    try writer.print("{s} at {d}:{d}\n", .{ @tagName(exception.exception), row + 1, col + 1 });

    var i: isize = @as(isize, @intCast(row)) - 1;
    const end: isize = @as(isize, @intCast(row)) + 1;

    while (i <= end) : (i += 1) {
        if (i < 0) continue;

        const line_idx = @as(usize, @intCast(i));
        if (map.getLine(line_idx)) |line_content| {
            try writer.print("{d: >4} | {s}\n", .{ line_idx + 1, line_content });

            if (line_idx == row) {
                try writer.print("       ", .{});

                var s: usize = 0;
                while (s < col) : (s += 1) try writer.print(" ", .{});
                while (s < col + exception.node.src.len - 1) : (s += 1) try writer.print("^", .{});

                try writer.print("^\n", .{});
            }
        }
    }
    try writer.print("\n", .{});
}
