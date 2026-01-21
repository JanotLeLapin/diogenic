const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerExceptionData = compiler.CompilerExceptionData;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const State = struct {
    bindings: std.StringHashMap(std.ArrayList([]const u8)),
    alloc: std.mem.Allocator,

    fn init(alloc: std.mem.Allocator) !State {
        return .{
            .bindings = try std.StringHashMap(std.ArrayList([]const u8)).init(alloc),
            .alloc = alloc,
        };
    }

    fn register(self: *State, name: []const u8) !void {
        const maybe_arr = self.bindings.getPtr(name);

        const count = blk: {
            if (maybe_arr) |arr| {
                break :blk arr.items.len;
            } else {
                break :blk 0;
            }
        };

        const new_name = try self.alloc.alloc(u8, name.len + 8);
        _ = try std.fmt.bufPrint(new_name, "{s}_{d}", .{ name, count });

        if (maybe_arr) |arr| {
            try arr.append(self.alloc, new_name);
        } else {
            var arr = try std.ArrayList([]const u8).initCapacity(
                self.alloc,
                8,
            );
            try arr.append(self.alloc, new_name);
            try self.bindings.put(
                name,
                arr,
            );
        }
    }

    fn release(self: *State, name: []const u8) void {
        if (self.bindings.getPtr(name)) |arr| {
            _ = arr.pop();
        }
    }

    fn get(self: *const State, name: []const u8) ?[]const u8 {
        if (self.bindings.get(name)) |arr| {
            if (0 == arr.items.len) {
                return null;
            }

            return arr.getLast();
        }

        return null;
    }
};

fn renameLet(env: *State, node: *Node) anyerror!void {
    const bindings = node.data.list.items[1];
    const body = node.data.list.items[2];

    var i: usize = 1;
    while (i < bindings.data.list.items.len) : (i += 2) {
        try expand(env, bindings.data.list.items[i]);
    }

    var old_names = try std.ArrayList([]const u8).initCapacity(
        env.alloc,
        bindings.data.list.items.len / 2,
    );

    i = 0;
    while (i < bindings.data.list.items.len) : (i += 2) {
        const key = bindings.data.list.items[i];
        const old_name = key.data.id;
        try old_names.append(env.alloc, old_name);
        try env.register(old_name);

        if (env.get(old_name)) |new_name| {
            key.data.id = new_name;
        }
    }

    try expand(env, body);

    for (old_names.items) |name| {
        env.release(name);
    }
}

pub fn expand(env: *State, node: *Node) anyerror!void {
    switch (node.data) {
        .id => |name| {
            if (env.get(name)) |new_name| {
                node.data.id = new_name;
            }
        },
        .list => |lst| {
            if (lst.items.len == 0) return;

            const is_let = switch (lst.items[0].data) {
                .id => |id| std.mem.eql(u8, "let", id),
                else => false,
            };
            if (is_let) {
                try renameLet(env, node);
            } else {
                for (lst.items) |child| {
                    try expand(env, child);
                }
            }
        },
        else => {},
    }
}
