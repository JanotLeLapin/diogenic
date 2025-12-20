const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Push = struct {
    pub const name = "push";

    pub const input_count = 0;
    pub const output_count = 1;

    value: f32,

    pub fn compile(_: *CompilerState, _: *Node) !Push {
        return error.NotCallable;
    }

    pub fn eval(
        self: *const Push,
        _: []const Block,
        outputs: []Block,
        _: *EngineState,
    ) void {
        const out = &outputs[0];
        for (&out.channels) |*chan| {
            for (chan) |*vec| {
                vec.* = @splat(self.value);
            }
        }
    }
};

pub const Pop = struct {
    pub const name = "pop";

    pub const input_count = 1;
    pub const output_count = 0;

    pub fn compile(_: *CompilerState, _: *Node) !Pop {
        return error.NotCallable;
    }

    pub fn eval(
        _: *const Pop,
        _: []const Block,
        _: []Block,
        _: *EngineState,
    ) void {}
};

pub const Store = struct {
    pub const name = "store";

    pub const input_count = 1;
    pub const output_count = 0;

    reg_index: usize,

    pub fn compile(_: *CompilerState, _: *Node) !Store {
        return error.NotCallable;
    }

    pub fn eval(
        self: *const Store,
        inputs: []const Block,
        _: []Block,
        state: *EngineState,
    ) void {
        const b = &inputs[0];
        state.reg[self.reg_index] = b.*;
    }
};

pub const Load = struct {
    pub const name = "load";

    pub const input_count = 0;
    pub const output_count = 1;

    reg_index: usize,

    pub fn compile(_: *CompilerState, _: *Node) !Load {
        return error.NotCallable;
    }

    pub fn eval(
        self: *const Load,
        _: []const Block,
        outputs: []Block,
        state: *EngineState,
    ) void {
        const b = &outputs[0];
        b.* = state.reg[self.reg_index];
    }
};

pub const Free = struct {
    pub const name = "free";

    pub const input_count = 0;
    pub const output_count = 0;

    reg_index: usize,

    pub fn compile(_: *CompilerState, _: *Node) !Free {
        return error.NotCallable;
    }

    pub fn eval(
        _: *const Free,
        _: []const Block,
        _: []Block,
        _: *EngineState,
    ) void {
        // TODO: free
    }
};
