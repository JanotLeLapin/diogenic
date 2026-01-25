const builtin = @import("builtin");
const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerExceptionData = compiler.CompilerExceptionData;

const parser = @import("../parser.zig");
const Node = parser.Node;
const Tokenizer = parser.Tokenizer;

const DiogenicStd = @import("diogenic-std").Standard;

pub const Function = struct {
    node: *Node,
    doc: ?[]const u8,
};

pub const State = struct {
    exceptions: *std.ArrayList(CompilerExceptionData),
    func: std.StringHashMap(Function),
    exceptions_alloc: std.mem.Allocator,
    func_alloc: std.mem.Allocator,
    ast_alloc: std.mem.Allocator,
    stack_alloc: std.mem.Allocator,
};

pub fn expandFunction(
    state: *State,
    tmp: *Node,
    func: *Node,
) anyerror!bool {
    const args = func.data.list.items[2].data.list.items;
    const expr = func.data.list.items[3];

    if (tmp.data.list.items.len - 1 != args.len) {
        try state.exceptions.append(state.exceptions_alloc, .{
            .exception = .bad_arity,
            .node = tmp,
        });
        return false;
    }

    const letNode = try state.ast_alloc.create(Node);
    letNode.* = .{
        .pos = tmp.pos,
        .data = .{ .id = "let" },
        .src = "FUNC",
    };

    const bindingsNode = try state.ast_alloc.create(Node);
    bindingsNode.* = .{
        .pos = tmp.pos,
        .data = .{
            .list = try std.ArrayList(*Node).initCapacity(state.ast_alloc, args.len * 2),
        },
        .src = "FUNC",
    };

    for (args, tmp.data.list.items[1..]) |arg_name, arg_value| {
        try bindingsNode.data.list.append(state.ast_alloc, arg_name);
        try bindingsNode.data.list.append(state.ast_alloc, arg_value);
    }

    const resNode = try state.ast_alloc.create(Node);
    resNode.* = .{
        .pos = tmp.pos,
        .data = .{
            .list = try std.ArrayList(*Node).initCapacity(state.ast_alloc, 3),
        },
        .src = "FUNC",
    };

    try resNode.data.list.append(state.ast_alloc, letNode);
    try resNode.data.list.append(state.ast_alloc, bindingsNode);
    try resNode.data.list.append(state.ast_alloc, expr);

    tmp.* = resNode.*;

    return true;
}

fn expand(state: *State, node: *Node) !bool {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return true,
    };

    if (0 == expr.len) {
        return true;
    }

    switch (expr[0].data) {
        .id => |op| {
            if (state.func.get(op)) |func| {
                if (!try expandFunction(state, node, func.node)) {
                    return false;
                }

                return expand(state, node);
            }
        },
        else => {},
    }

    var failed = false;
    for (expr) |child| {
        if (!try expand(state, child)) {
            failed = true;
        }
    }
    return !failed;
}

pub fn analyze(state: *State, root: *Node) !bool {
    var failed = false;
    var i: usize = 0;
    while (i < root.data.list.items.len) {
        const child = root.data.list.items[i];
        if (std.mem.eql(u8, "use", child.data.list.items[0].data.id)) {
            const maybe_src = blk: {
                switch (child.data.list.items[1].data) {
                    .str => |path| {
                        if (builtin.target.os.tag == .freestanding) {
                            break :blk null;
                        }
                        const file = std.fs.cwd().openFile(path, .{}) catch break :blk null;
                        defer file.close();

                        break :blk file.readToEndAlloc(state.ast_alloc, 10 * 1024 * 1024) catch break :blk null;
                    },
                    .id => |path| break :blk DiogenicStd.get(path),
                    else => break :blk null,
                }
            };

            const src = maybe_src orelse {
                try state.exceptions.append(state.exceptions_alloc, .{
                    .exception = .unresolved_import,
                    .node = child,
                });
                i += 1;
                failed = true;
                continue;
            };

            var t: Tokenizer = .{ .src = src };
            const ast = try parser.parse(&t, state.ast_alloc, state.stack_alloc);
            _ = root.data.list.orderedRemove(i);
            try root.data.list.insertSlice(state.ast_alloc, i, ast.data.list.items);
            continue;
        } else if (std.mem.eql(u8, "defun", child.data.list.items[0].data.id)) {
            switch (child.data.list.items[3].data) {
                .str => |doc| {
                    _ = child.data.list.orderedRemove(3);
                    try state.func.put(child.data.list.items[1].data.id, .{
                        .node = child,
                        .doc = doc,
                    });
                },
                else => {
                    try state.func.put(child.data.list.items[1].data.id, .{
                        .node = child,
                        .doc = null,
                    });
                },
            }
        } else {
            if (!try expand(state, child)) {
                failed = true;
            }
        }
        i += 1;
    }

    return !failed;
}
