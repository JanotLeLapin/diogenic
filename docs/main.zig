const std = @import("std");

const core = @import("diogenic-core");

pub fn main() void {
    inline for (core.instruction.Instructions) |T| {
        if (@hasDecl(T, "description")) {
            std.debug.print("## `" ++ T.name ++ "`\n\n" ++ T.description ++ "\n\n", .{});
            if (T.args.len > 0) {
                inline for (T.args) |arg| {
                    std.debug.print("- " ++ arg.name, .{});
                    if (arg.default) |default| {
                        std.debug.print(", default: `{d}`", .{default});
                    }
                    if (arg.description) |description| {
                        std.debug.print(", " ++ description, .{});
                    }
                    std.debug.print("\n", .{});
                }
                std.debug.print("\n", .{});
            }
        }
    }
}
