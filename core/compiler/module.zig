const builtin = @import("builtin");
const std = @import("std");

const Standard = @import("diogenic-std").Standard;

const util = @import("util.zig");

const types = @import("types.zig");
const Argument = types.Argument;
const ArgumentMap = types.ArgumentMap;
const Function = types.Function;
const FunctionMap = types.FunctionMap;
const Module = types.Module;
const ModuleMap = types.ModuleMap;
const SourceMap = types.SourceMap;
const State = types.State;

const macroExpand = @import("macro.zig").expand;

const parser = @import("../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

fn resolveUse(node: *Node, file_alloc: std.mem.Allocator) ?struct {
    []const u8,
    []const u8,
} {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return null,
    };

    if (2 > expr.len) {
        return null;
    }

    const op = switch (expr[0].data) {
        .id => |id| id,
        else => return null,
    };

    if (!std.mem.eql(u8, "use", op)) {
        return null;
    }

    switch (expr[1].data) {
        .id => |std_path| {
            const src = Standard.get(std_path) orelse return null;
            return .{ std_path, src };
        },
        .str => |local_path| {
            if (builtin.target.os.tag == .freestanding) {
                return null;
            }
            const file = std.fs.cwd().openFile(local_path, .{}) catch return null;
            defer file.close();

            const src = file.readToEndAlloc(file_alloc, 10 * 1024 * 1024) catch return null;
            return .{ local_path, src };
        },
        else => return null,
    }
}

fn resolveArg(node: *Node) ?struct {
    []const u8,
    Argument,
} {
    const lst = switch (node.data) {
        .id => |id| {
            return .{ id, Argument{
                .id_node = node,
                .doc = null,
                .default = null,
            } };
        },
        .list => |lst| lst.items,
        else => return null,
    };

    if (1 > lst.len) {
        return null;
    }

    const arg_name = switch (lst[0].data) {
        .id => |id| id,
        else => return null,
    };

    var arg: Argument = .{
        .id_node = lst[0],
        .doc = null,
        .default = null,
    };

    var i: usize = 1;
    while (i < lst.len - 1) : (i += 2) {
        const atom = switch (lst[i].data) {
            .atom => |atom| atom,
            else => continue, // FIXME: throw exception
        };

        if (std.mem.eql(u8, ":doc", atom)) {
            const doc = switch (lst[i + 1].data) {
                .str => |str| str,
                else => continue,
            };
            arg.doc = doc;
        } else if (std.mem.eql(u8, ":default", atom)) {
            const default = switch (lst[i + 1].data) {
                .num => |num| num,
                else => continue,
            };
            arg.default = default;
        } else {
            // FIXME: throw exception here as well
        }
    }

    return .{ arg_name, arg };
}

fn resolveFunc(node: *Node, alloc: std.mem.Allocator) !?struct {
    []const u8,
    Function,
} {
    const op, const expr = util.getExpr(node) orelse return null;

    if (!std.mem.eql(u8, "defun", op) or 3 > expr.len) {
        return null;
    }

    const fn_name = switch (expr[0].data) {
        .id => |id| id,
        else => return null,
    };

    const arg_nodes = switch (expr[1].data) {
        .list => |lst| lst.items,
        else => return null,
    };

    var args = try std.ArrayList([]const u8).initCapacity(alloc, 1);
    var arg_map = ArgumentMap.init(alloc);

    for (arg_nodes) |arg_node| {
        const arg_name, const arg = resolveArg(arg_node) orelse return null;

        try args.append(alloc, arg_name);
        try arg_map.put(arg_name, arg);
    }

    const func = switch (expr[2].data) {
        .str => |str| Function{
            .body = expr[3],
            .args = args,
            .arg_map = arg_map,
            .doc = str,
        },
        .list => Function{
            .body = expr[2],
            .args = args,
            .arg_map = arg_map,
            .doc = null,
        },
        else => return null,
    };

    return .{ fn_name, func };
}

pub fn resolveImports(
    state: *State,
    name: []const u8,
    src: []const u8,
) !*Module {
    var t: Tokenizer = .{ .src = src };
    const ast = try parser.parse(&t, state.arena_alloc, state.stack_alloc, name);

    try macroExpand(state, ast);

    var imports = try std.ArrayList(*Module).initCapacity(state.arena_alloc, 1);
    var functions = FunctionMap.init(state.arena_alloc);

    for (ast.data.list.items) |child| {
        if (resolveUse(child, state.arena_alloc)) |res| {
            const use_name, const use_src = res;
            const use_mod = state.map.get(use_name) orelse blk: {
                const use_mod = try resolveImports(state, use_name, use_src);
                try state.map.put(use_name, use_mod);
                break :blk use_mod;
            };

            try imports.append(state.arena_alloc, use_mod);
        } else if (try resolveFunc(child, state.arena_alloc)) |res| {
            const func_name, const func = res;
            try functions.put(func_name, func);
        }
    }

    const mod = try state.arena_alloc.create(Module);
    mod.* = .{
        .root = ast,
        .imports = imports,
        .functions = functions,
        .sourcemap = try SourceMap.init(src, state.arena_alloc),
    };

    return mod;
}
