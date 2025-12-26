const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

inline fn clamp2pi(a: Vec) Vec {
    return @min(@as(Vec, @splat(1.0)), @max(@as(Vec, @splat(0.0)), a));
}

pub const Pan = struct {
    pub const name = "pan";
    pub const description = "pan signal between left and right channels";

    pub const args: []const meta.Arg = &.{
        .{ .name = "alpha", .description = "panning modifier: 0 = all left, 0.5 = middle, 1 = all right." },
        .{ .name = "in", .description = "input signal" },
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
        const alpha = &inputs[0];
        const in = &inputs[1];
        const out = &outputs[0];
        for (alpha.channels[0], in.channels[0], 0..) |alpha_vec, in_vec, i| {
            const norm = clamp2pi(alpha_vec) * @as(Vec, @splat(std.math.pi / 2.0));
            const g = @cos(norm);
            out.channels[0][i] = in_vec * g;
        }
        for (alpha.channels[1], in.channels[1], 0..) |alpha_vec, in_vec, i| {
            const norm = clamp2pi(alpha_vec) * @as(Vec, @splat(std.math.pi / 2.0));
            const g = @sin(norm);
            out.channels[1][i] = in_vec * g;
        }
    }
};
