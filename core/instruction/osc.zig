const std = @import("std");

const compiler = @import("../compiler.zig");
const CompilerState = compiler.CompilerState;

const engine = @import("../engine.zig");
const Block = engine.Block;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (f32) f32;
pub const OpVec = fn (Vec) Vec;

pub fn Osc(comptime label: [:0]const u8, comptime op: Op, comptime op_vec: OpVec) type {
    return struct {
        pub const name = label;

        phase_index: usize,
        static_freq: ?f32,

        pub fn compile(state: *CompilerState, expr: *Node) !@This() {
            const self = @This(){
                .phase_index = state.state_index,
                .static_freq = switch (expr.data.list.items[1].data) {
                    .num => |num| num,
                    else => null,
                },
            };
            state.state_index += 1;
            return self;
        }

        pub fn evalDynamic(state: *EngineState, freq: *const Block, pm: *const Block, phase: *f32, out: *Block) void {
            var acc: f32 = 0.0;
            for (freq.channels, pm.channels, 0..) |freq_chan, pm_chan, i| {
                acc = phase.*;
                for (freq_chan, pm_chan, 0..) |freq_vec, pm_vec, j| {
                    const inc_vec = freq_vec / @as(Vec, @splat(state.sr));
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

        pub fn evalStatic(state: *EngineState, freq: f32, pm: *const Block, phase: *f32, out: *Block) void {
            const inc = freq / state.sr;

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

        pub fn eval(self: *const @This(), state: *EngineState) void {
            const pm = state.popStack();
            const freq = state.popStack();
            const phase = &state.state[self.phase_index];
            const out = state.reserveStack();

            if (self.static_freq) |v| {
                evalStatic(state, v, pm, phase, out);
            } else {
                evalDynamic(state, freq, pm, phase, out);
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

pub const Sine = Osc("sine", sine, sineVec);
pub const Sawtooth = Osc("sawtooth", sawtooth, sawtoothVec);
pub const Square = Osc("square", square, squareVec);
