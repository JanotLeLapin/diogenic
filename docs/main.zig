const std = @import("std");

const core = @import("diogenic-core");

pub fn main() void {
    std.debug.print("*This version of diogenic includes `{d}` devices.*\n\n", .{core.instruction.Instructions.len});
    inline for (core.instruction.Instructions) |T| {
        if (T.name[0] != '_') {
            const desc = if (@hasDecl(T, "description")) T.description else "*no description provided*";
            std.debug.print(
                "### `" ++ T.name ++ "`\n\n" ++ desc ++ ". `{d}` argument{s}.\n\n",
                .{
                    T.args.len,
                    if (T.args.len == 1) "" else "s",
                },
            );
            if (T.args.len > 0) {
                inline for (T.args) |arg| {
                    std.debug.print("- " ++ arg.name, .{});
                    if (arg.default) |default| {
                        std.debug.print(", default: `{d}`", .{default});
                    }
                    if (arg.description) |a_desc| {
                        std.debug.print(", " ++ a_desc, .{});
                    }
                    std.debug.print("\n", .{});
                }
                std.debug.print("\n", .{});
            }
        }
    }
}
