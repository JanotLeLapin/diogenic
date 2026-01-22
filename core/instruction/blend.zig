const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Blend = struct {
    pub const name = "blend";
    pub const description = "weighted average of two input signals";

    pub const args: []const meta.Arg = &.{
        .{ .name = "a", .description = "first signal" },
        .{ .name = "b", .description = "second signal" },
        .{ .name = "alpha", .description = "weighted average coefficient" },
    };

    pub fn compile(_: engine.CompileData) !@This() {
        return @This(){};
    }

    pub fn eval(_: *const @This(), d: engine.EvalData) void {
        const a = &d.inputs[0];
        const b = &d.inputs[1];
        const w = &d.inputs[2];

        for (a.channels, b.channels, w.channels, &d.output.channels) |a_chan, b_chan, w_chan, *out_chan| {
            for (a_chan, b_chan, w_chan, out_chan) |a_vec, b_vec, w_vec, *out_vec| {
                out_vec.* = w_vec * a_vec + (@as(Vec, @splat(1.0)) - w_vec) * b_vec;
            }
        }
    }
};
