const engine = @import("../engine.zig");
const Block = engine.Block;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Value = struct {
    pub const name = "value";

    value: f32,

    pub fn compile(node: *Node) !Value {
        const num = switch (node.data) {
            .num => |num| num,
            else => return error.UnexpectedNode,
        };

        return Value{ .value = num };
    }

    pub fn eval(self: *const Value, _: *EngineState, out: *Block) void {
        for (&out.channels) |*chan| {
            for (chan) |*vec| {
                vec.* = @splat(self.value);
            }
        }
    }
};
