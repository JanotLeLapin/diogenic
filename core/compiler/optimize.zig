const std = @import("std");

const parser = @import("../parser.zig");
const Node = parser.Node;

const Binding = struct {
    node: *Node,
    refcount: usize,

    fn shouldPropagate(self: *const Binding) bool {
        if (1 >= self.refcount) {
            return true;
        }

        switch (self.node.data) {
            .num => return true,
            else => {},
        }

        return false;
    }
};

fn countBindings(map: std.StringHashMap(Binding), node: *Node) void {
    const expr = switch (node.data) {
        .id => |id| {
            if (map.getPtr(id)) |binding| {
                binding.refcount += 1;
            }
            return;
        },
        .list => |lst| lst.items,
        else => return,
    };

    for (expr) |child| {
        countBindings(map, child);
    }
}

fn propagateBindings(map: std.StringHashMap(Binding), node: *Node) !void {
    const expr = switch (node.data) {
        .id => |id| {
            if (map.get(id)) |binding| {
                if (binding.shouldPropagate()) {
                    node.data = binding.node.data;
                    try propagateBindings(map, node);
                }
            }
            return;
        },
        .list => |lst| lst.items,
        else => return,
    };

    for (expr) |child| {
        switch (child.data) {
            .list, .id => try propagateBindings(map, child),
            else => {},
        }
    }
}

pub fn optimizeLet(map_alloc: std.mem.Allocator, node: *Node) !void {
    var map = std.StringHashMap(Binding).init(map_alloc);
    defer map.deinit();

    const bindings = node.data.list.items[1];
    const body = node.data.list.items[2];

    var i: usize = 0;
    while (i < bindings.data.list.items.len) : (i += 2) {
        try map.put(
            bindings.data.list.items[i].data.id,
            .{
                .node = bindings.data.list.items[i + 1],
                .refcount = 0,
            },
        );
    }

    // count references
    i = 0;
    while (i < bindings.data.list.items.len) : (i += 2) {
        countBindings(map, bindings.data.list.items[i + 1]);
    }
    countBindings(map, body);

    i = 0;
    while (i < bindings.data.list.items.len) {
        const binding = map.get(bindings.data.list.items[i].data.id).?;
        if (binding.shouldPropagate()) {
            _ = bindings.data.list.orderedRemove(i);
            _ = bindings.data.list.orderedRemove(i);
        } else {
            i += 2;
        }
    }

    // propagate
    i = 0;
    while (i < bindings.data.list.items.len) : (i += 2) {
        try propagateBindings(map, bindings.data.list.items[i + 1]);
    }
    try propagateBindings(map, body);
}

pub fn optimize(map_alloc: std.mem.Allocator, node: *Node) !void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return,
    };

    if (0 == expr.len) {
        return;
    }

    switch (expr[0].data) {
        .id => |op| {
            if (std.mem.eql(u8, "let", op)) {
                try optimizeLet(map_alloc, node);
            }
        },
        else => {},
    }

    for (expr[0..]) |child| {
        try optimize(map_alloc, child);
    }
}
