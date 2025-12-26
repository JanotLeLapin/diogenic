const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Chebyshev = struct {
    pub const name = "chebyshev";
    pub const description = "first kind Chebyshev function";

    pub const args: []const meta.Arg = &.{
        .{ .name = "order" },
        .{ .name = "in" },
    };

    pub fn compile(_: *Node) !@This() {
        return @This(){};
    }

    pub fn eval(
        _: *const @This(),
        _: f32,
        inputs: []const Block,
        outputs: []Block,
        _: []f32,
        _: []Block,
    ) void {
        const order = &inputs[0];
        const in = &inputs[1];
        const out = &outputs[0];

        for (order.channels, in.channels, &out.channels) |order_chan, in_chan, *out_chan| {
            for (order_chan, in_chan, out_chan) |order_vec, in_vec, *out_vec| {
                const acos_in = blk: {
                    var vec: Vec = undefined;
                    for (0..engine.SIMD_LENGTH) |i| {
                        vec[i] = std.math.acos(in_vec[i]);
                    }
                    break :blk vec;
                };
                out_vec.* = @cos(order_vec * acos_in);
            }
        }
    }
};
