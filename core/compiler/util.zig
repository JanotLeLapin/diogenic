const parser = @import("../parser.zig");
const Node = parser.Node;

pub fn getExpr(node: *Node) ?struct {
    []const u8,
    []*Node,
} {
    const expr = switch (node.data) {
        .list => |lst| lst.items,
        else => return null,
    };

    if (0 == expr.len) {
        return null;
    }

    const id = switch (expr[0].data) {
        .id => |id| id,
        else => return null,
    };

    return .{ id, expr[1..] };
}
