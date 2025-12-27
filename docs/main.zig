const std = @import("std");

const core = @import("diogenic-core");

pub fn main() void {
    std.debug.print("*This version of diogenic includes `{d}` devices.*\n\n", .{core.instruction.Instructions.len});
    inline for (core.instruction.Instructions) |T| {
        if (@hasDecl(T, "description")) {
            std.debug.print(
                "### `" ++ T.name ++ "`\n\n" ++ T.description ++ ". `{d}` argument{s}.\n\n",
                .{
                    T.args.len,
                    if (T.args.len == 1) "" else "s",
                },
            );
            if (T.args.len > 0) {
                var flag = false;
                inline for (T.args) |arg| {
                    if (arg.description) |description| {
                        flag = true;
                        std.debug.print("- " ++ arg.name, .{});
                        if (arg.default) |default| {
                            std.debug.print(", default: `{d}`", .{default});
                        }
                        std.debug.print(", " ++ description ++ "\n", .{});
                    }
                }
                if (flag) {
                    std.debug.print("\n", .{});
                }
            }
        }
    }
}
