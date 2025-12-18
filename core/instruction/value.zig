const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Push = struct {
    pub const name = "push";

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

    pub fn eval(_: *const Pop, state: *EngineState) void {
        _ = state.popStack();
    }
};

pub const Store = struct {
    pub const name = "store";

    reg_index: usize,

    pub fn compile(state: *CompilerState, _: *Node) !Store {
        const self = @This(){ .reg_index = state.reg_index };
        state.reg_index += 1;
        return self;
    }

    pub fn eval(self: *const Store, state: *EngineState) void {
        const b = state.popStack();
        state.reg[self.reg_index] = b.*;
    }
};

pub const Load = struct {
    pub const name = "load";

    reg_index: usize,

    pub fn compile(_: *CompilerState, _: *Node) !Load {
        @panic("attempted to compile low level instruction");
    }

    pub fn eval(self: *const Load, state: *EngineState) void {
        const b = state.reserveStack();
        b.* = state.reg[self.reg_index];
    }
};

pub const Free = struct {
    pub const name = "free";

    reg_index: usize,

    pub fn compile(state: *CompilerState, _: *Node) !Free {
        const self = @This(){ .reg_index = state.reg_index };
        state.reg_index += 1;
        return self;
    }

    pub fn eval(_: *const Free, _: *EngineState) void {
        // TODO: free
    }
};
