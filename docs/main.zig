const std = @import("std");

const core = @import("diogenic-core");
const Standard = @import("diogenic-std").Standard;

const parser = core.parser;
const Tokenizer = parser.Tokenizer;

fn generateDeviceDocs() void {
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

fn generateStdDocs(gpa: std.mem.Allocator, file: []const u8) !void {
    const src = Standard.get(file) orelse return;

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var t = Tokenizer{ .src = src };
    const root = try parser.parse(&t, arena.allocator(), gpa);

    var exceptions = try std.ArrayList(core.compiler.CompilerExceptionData).initCapacity(arena.allocator(), 1);

    var inline_state = core.compiler.inline_pass.State{
        .exceptions = &exceptions,
        .func = std.StringHashMap(core.compiler.inline_pass.Function).init(arena.allocator()),
        .exceptions_alloc = arena.allocator(),
        .func_alloc = arena.allocator(),
        .ast_alloc = arena.allocator(),
        .stack_alloc = arena.allocator(),
    };
    defer inline_state.func.deinit();

    if (!try core.compiler.inline_pass.analyze(&inline_state, root)) {
        return;
    }

    var func_key_iter = inline_state.func.keyIterator();
    while (func_key_iter.next()) |func_key| {
        const func = inline_state.func.get(func_key.*).?;
        std.debug.print("### `{s}`\n\n{s}\n\n", .{ func_key.*, func.doc orelse "*no description*" });

        var arg_key_iter = func.args.keyIterator();
        while (arg_key_iter.next()) |arg_key| {
            const arg = func.args.get(arg_key.*).?;
            std.debug.print("- `{s}`", .{arg_key.*});
            if (arg.doc) |doc| {
                std.debug.print(", {s}", .{doc});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n```scm\n{s}\n```\n\n", .{func.node.src});
    }
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const args = std.process.argsAlloc(gpa.allocator()) catch return;
    defer std.process.argsFree(gpa.allocator(), args);

    if (args.len > 1 and std.mem.eql(u8, args[1], "--stdlib")) {
        if (args.len < 3) {
            return;
        }
        const file_path = args[2];
        generateStdDocs(gpa.allocator(), file_path) catch return;
    } else {
        generateDeviceDocs();
    }
}
