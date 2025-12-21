const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (Vec, Vec) Vec;

pub fn Arith(comptime label: [:0]const u8, comptime op: Op) type {
    return struct {
        pub const name = label;

        pub const input_count = 2;
        pub const output_count = 1;

        pub fn compile(_: *CompilerState, node: *Node) !@This() {
            if (node.data.list.items.len != 3) {
                return error.BadArity;
            }
            return @This(){};
        }

        pub fn eval(
            _: *const @This(),
            inputs: []const Block,
            outputs: []Block,
            _: []f32,
            _: []Block,
        ) void {
            const lhs = &inputs[0];
            const rhs = &inputs[1];
            const out = &outputs[0];

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

inline fn cmp(mask: @Vector(engine.SIMD_LENGTH, bool)) Vec {
    return @select(f32, mask, @as(Vec, @splat(0.0)), @as(Vec, @splat(1.0)));
}

fn lt(left: Vec, right: Vec) Vec {
    return cmp(left < right);
}

fn leq(left: Vec, right: Vec) Vec {
    return cmp(left <= right);
}

fn gt(left: Vec, right: Vec) Vec {
    return cmp(left > right);
}

fn geq(left: Vec, right: Vec) Vec {
    return cmp(left >= right);
}

pub const Add = Arith("+", add);
pub const Sub = Arith("-", sub);
pub const Mul = Arith("*", mul);
pub const Div = Arith("/", div);
pub const Lt = Arith("<", lt);
pub const Leq = Arith("<=", leq);
pub const Gt = Arith(">", gt);
pub const Geq = Arith(">=", geq);
