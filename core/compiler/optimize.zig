const std = @import("std");

const parser = @import("../parser.zig");
const Node = parser.Node;

fn optimizeLetBody(map: std.StringHashMap(*Node), node: *Node) !void {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return,
    };

    for (expr) |child| {
        switch (child.data) {
            .id => |id| {
                if (map.get(id)) |binding| {
                    switch (binding.data) {
                        .num => {
                            child.data = binding.data;
                        },
                        else => {},
                    }
                }
            },
            .list => try optimizeLetBody(map, child),
            else => {},
        }
    }
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
                var map = std.StringHashMap(*Node).init(map_alloc);
                defer map.deinit();

                const bindings = node.data.list.items[1];

                var i: usize = 0;
                while (i < bindings.data.list.items.len) {
                    try map.put(
                        bindings.data.list.items[i].data.id,
                        bindings.data.list.items[i + 1],
                    );

                    switch (bindings.data.list.items[i + 1].data) {
                        .num => {
                            _ = bindings.data.list.orderedRemove(i);
                            _ = bindings.data.list.orderedRemove(i);
                        },
                        else => i += 2,
                    }
                }

                try optimizeLetBody(map, node.data.list.items[2]);
            }
        },
        else => {},
    }

    for (expr[0..]) |child| {
        try optimize(map_alloc, child);
    }
}
