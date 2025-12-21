const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (f32) f32;
pub const OpVec = fn (Vec) Vec;

pub fn Osc(comptime label: [:0]const u8, comptime op: Op, comptime op_vec: OpVec) type {
    return struct {
        pub const name = label;

        pub const input_count = 2;
        pub const output_count = 1;
        pub const state_count = 1;

        static_freq: ?f32,

        pub fn compile(_: *CompilerState, node: *Node) !@This() {
            return @This(){
                .static_freq = switch (node.data.list.items[1].data) {
                    .num => |num| num,
                    else => null,
                },
            };
        }

        pub fn evalDynamic(freq: *const Block, pm: *const Block, phase: *f32, out: *Block) void {
            var acc: f32 = 0.0;
            for (freq.channels, pm.channels, 0..) |freq_chan, pm_chan, i| {
                acc = phase.*;
                for (freq_chan, pm_chan, 0..) |freq_vec, pm_vec, j| {
                    // const inc_vec = freq_vec / @as(Vec, @splat(state.sr));
                    // FIXME: hardcoded sample rate
                    const inc_vec = freq_vec / @as(Vec, @splat(48000.0));
                    for (0..engine.SIMD_LENGTH) |k| {
                        const inc = inc_vec[k];

                        const radians = std.math.pi * 2 * acc;
                        out.channels[i][j][k] = op(radians + pm_vec[k]);

                        acc += inc;
                        acc -= @floor(acc);
                    }
                }
            }

            phase.* = acc;
        }

        pub fn evalStatic(freq: f32, pm: *const Block, phase: *f32, out: *Block) void {
            // const inc = freq / state.sr;
            // FIXME: hardcoded sample rate
            const inc = freq / 48000.0;

            var ramp: Vec = undefined;
            inline for (0..engine.SIMD_LENGTH) |i| {
                ramp[i] = inc * @as(f32, @floatFromInt(i));
            }

            const block_inc = inc * @as(f32, @floatFromInt(engine.SIMD_LENGTH));

            var acc: f32 = 0.0;
            for (pm.channels, 0..) |pm_chan, i| {
                acc = phase.*;
                for (pm_chan, 0..) |pm_vec, j| {
                    const v_phase = @as(Vec, @splat(acc)) + ramp + pm_vec;
                    const v_phase_wrapped = v_phase - @floor(v_phase);

                    const radians = @as(Vec, @splat(std.math.pi * 2)) * v_phase_wrapped;
                    out.channels[i][j] = op_vec(radians);

                    acc += block_inc;
                    acc -= @floor(acc);
                }
            }

            phase.* = acc;
        }

        pub fn eval(
            self: *const @This(),
            inputs: []const Block,
            outputs: []Block,
            state: []f32,
            _: []Block,
        ) void {
            const freq = &inputs[0];
            const pm = &inputs[1];
            const phase = &state[0];
            const out = &outputs[0];

            if (self.static_freq) |v| {
                evalStatic(v, pm, phase, out);
            } else {
                evalDynamic(freq, pm, phase, out);
            }
        }
    };
}

fn sine(p: f32) f32 {
    return @sin(p);
}

fn sineVec(p: Vec) Vec {
    return @sin(p);
}

fn sawtooth(p: f32) f32 {
    return p / std.math.pi - 1.0;
}

fn sawtoothVec(p: Vec) Vec {
    return p / @as(Vec, @splat(std.math.pi)) - @as(Vec, @splat(1.0));
}

fn square(p: f32) f32 {
    return @floor(p / std.math.pi) * 2.0 - 1.0;
}

fn squareVec(p: Vec) Vec {
    return @floor(p / @as(Vec, @splat(std.math.pi))) * @as(Vec, @splat(2.0)) - @as(Vec, @splat(1.0));
}

pub const Sine = Osc("sine!", sine, sineVec);
pub const Sawtooth = Osc("sawtooth!", sawtooth, sawtoothVec);
pub const Square = Osc("square!", square, squareVec);
