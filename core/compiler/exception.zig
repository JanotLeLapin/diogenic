const types = @import("types.zig");
const Exception = types.Exception;
const SourceMap = types.SourceMap;

const Colors = @import("../colors.zig");

pub fn printExceptionContext(
    map: SourceMap,
    exception: Exception,
    writer: anytype,
) !void {
    const row = exception.node.pos.row;
    const col = exception.node.pos.col;

    _ = try Colors.setMagenta(writer);
    try writer.print("{s}", .{@tagName(exception.t)});
    _ = try Colors.setReset(writer);
    try writer.print(" at {d}:{d}\n", .{
        row + 1,
        col + 1,
    });

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

                switch (exception.node.data) {
                    .list => {
                        try writer.print("^", .{});
                    },
                    else => {
                        while (s < col + exception.node.src.len) : (s += 1) try writer.print("^", .{});
                    },
                }

                try writer.print("\n", .{});
            }
        }
    }
    if (exception.message) |msg| {
        _ = try writer.write("     > ");
        _ = try Colors.setMagenta(writer);
        try writer.print("{s}", .{msg});
        _ = try Colors.setReset(writer);
    }
    try writer.print("\n", .{});
}
