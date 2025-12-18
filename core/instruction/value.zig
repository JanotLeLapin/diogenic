const compiler = @import("../compiler.zig");
const CompilerState = compiler.CompilerState;

const engine = @import("../engine.zig");
const Block = engine.Block;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Push = struct {
    pub const name = "value";

    value: f32,

    pub fn compile(_: *CompilerState, node: *Node) !Push {
        const num = switch (node.data) {
            .num => |num| num,
            else => return error.UnexpectedNode,
        };

        return Push{ .value = num };
    }

    pub fn eval(self: *const Push, state: *EngineState) void {
        const out = state.reserveStack();
        for (&out.channels) |*chan| {
            for (chan) |*vec| {
                vec.* = @splat(self.value);
            }
        }
    }
};

pub const Pop = struct {
    pub const name = "pop";

    pub fn compile(_: *CompilerState, _: *Node) !Pop {
        return Pop{};
    }

    pub fn eval(_: *const Push, state: *EngineState) void {
        _ = state.popStack();
    }
};
