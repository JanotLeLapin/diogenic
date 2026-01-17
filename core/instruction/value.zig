const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Push = struct {
    pub const name = "_push";

    pub const input_count = 0;
    pub const output_count = 1;

    value: f32,

    pub fn compile(_: *Node) !Push {
        return error.NotCallable;
    }
};

pub const Pop = struct {
    pub const name = "_pop";

    pub const input_count = 1;
    pub const output_count = 0;

    pub fn compile(_: *Node) !Pop {
        return error.NotCallable;
    }
};

pub const Store = struct {
    pub const name = "_store";

    pub const input_count = 1;
    pub const output_count = 0;

    reg_index: usize,

    pub fn compile(_: *Node) !Store {
        return error.NotCallable;
    }
};

pub const Load = struct {
    pub const name = "_load";

    pub const input_count = 0;
    pub const output_count = 1;

    reg_index: usize,

    pub fn compile(_: *Node) !Load {
        return error.NotCallable;
    }
};

pub const Free = struct {
    pub const name = "_free";

    pub const input_count = 0;
    pub const output_count = 0;

    reg_index: usize,

    pub fn compile(_: *Node) !Free {
        return error.NotCallable;
    }
};
