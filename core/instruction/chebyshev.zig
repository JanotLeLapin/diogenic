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
        .{ .name = "in" },
        .{ .name = "order" },
    };

    pub fn compile(_: engine.CompileData) !@This() {
        return @This(){};
    }

    pub fn eval(_: *const @This(), d: engine.EvalData) void {
        const in = &d.inputs[0];
        const order = &d.inputs[1];

        for (order.channels, in.channels, &d.output.channels) |order_chan, in_chan, *out_chan| {
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
