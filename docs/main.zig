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

    var mod_map = core.compiler.types.ModuleMap.init(arena.allocator());
    defer mod_map.deinit();

    var instr_seq = try std.ArrayList(core.instruction.Instruction).initCapacity(gpa, 8);
    defer instr_seq.deinit(gpa);

    var exceptions = try std.ArrayList(core.compiler.types.Exception).initCapacity(gpa, 8);
    defer exceptions.deinit(gpa);

    var env = std.StringHashMap(usize).init(gpa);
    defer env.deinit();

    var state = core.compiler.types.State{
        .map = &mod_map,
        .instr_seq = &instr_seq,
        .exceptions = &exceptions,
        .env = &env,
        .arena_alloc = arena.allocator(),
        .stack_alloc = gpa,
    };
    const mod = try core.compiler.module.resolveImports(&state, "main", src);

    var func_key_iter = mod.functions.keyIterator();
    while (func_key_iter.next()) |func_key| {
        const func = mod.functions.get(func_key.*).?;
        std.debug.print("### `{s}`\n\n{s}\n\n", .{ func_key.*, func.doc orelse "*no description*" });

        for (func.args.items) |arg_key| {
            const arg = func.arg_map.get(arg_key).?;
            std.debug.print("- `{s}`", .{arg_key});
            if (arg.doc) |doc| {
                std.debug.print(", {s}", .{doc});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n```scm\n  {s}\n```\n\n", .{func.body.src});
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
