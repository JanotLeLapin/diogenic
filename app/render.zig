const std = @import("std");

pub fn render(
    gpa: std.mem.Allocator,
    path: []const u8,
    sample_rate: f32,
    seconds: f32,
) !void {
    _ = gpa;
    std.log.debug("should render {d} secs of {s} at sr {d}", .{ seconds, path, sample_rate });
}
