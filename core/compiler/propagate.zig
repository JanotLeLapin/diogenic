const std = @import("std");

const types = @import("types.zig");
const State = types.State;

const util = @import("util.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

const Binding = struct {
    refcount: usize,
    is_const: bool,
    node: *Node,

    fn shouldPropagate(self: *const Binding) bool {
        return self.is_const or 1 >= self.refcount;
    }
};

const BindingMap = std.StringHashMap(Binding);

fn isLet(node: *Node) bool {
    const op, const expr = util.getExpr(node) orelse return false;

    if (!std.mem.eql(u8, "let", op)) {
        return false;
    }

    return 2 <= expr.len;
}

fn countRefs(map: *BindingMap, node: *Node) void {
    const lst = switch (node.data) {
        .list => |lst| lst.items,
        .id => |id| {
            if (map.getPtr(id)) |b| {
                b.refcount += 1;
            }
            return;
        },
        else => return,
    };

    for (lst) |child| {
        countRefs(map, child);
    }
}

fn propagate(map: *const BindingMap, node: *Node) void {
    const lst = switch (node.data) {
        .list => |lst| lst.items,
        .id => |id| {
            if (map.get(id)) |b| {
                if (b.shouldPropagate()) {
                    node.* = b.node.*;
                }
            }
            return;
        },
        else => return,
    };

    for (lst) |child| {
        propagate(map, child);
    }
}

fn expandLet(gpa: std.mem.Allocator, bindings: *std.ArrayList(*Node), body: *Node) !void {
    var map = BindingMap.init(gpa);
    defer map.deinit();

    var i: usize = 0;
    while (i < bindings.items.len - 1) : (i += 2) {
        const id = switch (bindings.items[i].data) {
            .id => |id| id,
            else => continue,
        };

        try map.put(id, .{
            .refcount = 0,
            .is_const = switch (bindings.items[i + 1].data) {
                .num => true,
                else => false,
            },
            .node = bindings.items[i + 1],
        });
    }

    const lst = switch (body.data) {
        .list => |lst| lst.items,
        else => return,
    };

    for (lst) |child| {
        countRefs(&map, child);
    }

    for (lst) |child| {
        propagate(&map, child);
    }

    i = 0;
    while (i < bindings.items.len) {
        const id = switch (bindings.items[i].data) {
            .id => |id| id,
            else => {
                i += 2;
                continue;
            },
        };

        if (map.get(id)) |b| {
            if (b.shouldPropagate()) {
                bindings.orderedRemoveMany(&.{ i, i + 1 });
                continue;
            }
        }

        i += 2;
    }
}

pub fn expand(state: *State, node: *Node) !void {
    _, const expr = util.getExpr(node) orelse return;

    if (isLet(node)) {
        try expandLet(
            state.stack_alloc,
            &expr[0].data.list,
            expr[1],
        ); // FIXME: check
    }

    for (expr) |child| {
        try expand(state, child);
    }
}
