const std = @import("std");

pub const Arg = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    default: ?f32 = null,
};

pub fn buildArgs(comptime args: []const Arg) std.StaticStringMap(Arg) {
    const T = std.meta.Tuple(&.{ []const u8, Arg });
    const kv_pairs = comptime blk: {
        var arr: [args.len]T = undefined;
        for (args, 0..) |arg, i| {
            arr[i] = .{ arg.name, arg };
        }
        break :blk arr;
    };
    return std.StaticStringMap(Arg).initComptime(kv_pairs);
}
