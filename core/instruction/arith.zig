const engine = @import("../engine.zig");
const Block = engine.Block;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (Vec, Vec) Vec;

pub fn ArithInstruction(comptime label: [:0]const u8, comptime op: Op) type {
    return struct {
        pub const name = label;

        pub fn compile(_: *Node) !@This() {
            return @This(){};
        }

        pub fn eval(state: *EngineState, out: *Block) void {
            const lhs = &state.stack.items[state.stack.items.len - 1];
            const rhs = &state.stack.items[state.stack.items.len - 2];

            for (lhs.channels, rhs.channels, 0..) |l_chan, r_chan, i| {
                for (l_chan, r_chan, 0..) |l_vec, r_vec, j| {
                    out.channels[i][j] = op(l_vec, r_vec);
                }
            }
        }
    };
}

fn add(lhs: Vec, rhs: Vec) Vec {
    return lhs + rhs;
}

fn sub(lhs: Vec, rhs: Vec) Vec {
    return lhs - rhs;
}

fn mul(lhs: Vec, rhs: Vec) Vec {
    return lhs * rhs;
}

fn div(lhs: Vec, rhs: Vec) Vec {
    return lhs / rhs;
}

pub const Add = ArithInstruction("+", add);
pub const Sub = ArithInstruction("-", sub);
pub const Mul = ArithInstruction("*", add);
pub const Div = ArithInstruction("/", sub);
