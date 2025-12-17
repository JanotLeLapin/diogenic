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

pub fn Osc(comptime label: [:0]const u8, comptime op: Op) type {
    return struct {
        pub const name = label;

        current_phase: usize,

        pub fn compile(state: *CompilerState, _: *Node) !@This() {
            const res = @This(){
                .current_phase = state.state_index,
            };
            state.state_index += 1;
            return res;
        }

        pub fn eval(self: *const @This(), state: *EngineState) void {
            const pm = state.popStack();
            const freq = state.popStack();
            const out = state.reserveStack();
            const phase = &state.state[self.current_phase];

            var acc: f32 = 0.0;
            for (freq.channels, pm.channels, 0..) |freq_channel, pm_channel, i| {
                acc = phase.*;
                for (freq_channel, pm_channel, 0..) |freq_vec, pm_vec, j| {
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
    };
}

fn sine(p: f32) f32 {
    return std.math.sin(p);
}

fn sawtooth(p: f32) f32 {
    return p / std.math.pi - 1.0;
}

fn square(p: f32) f32 {
    return @floor(p / std.math.pi) * 2.0 - 1.0;
}

pub const Sine = Osc("sine", sine);
pub const Sawtooth = Osc("sawtooth", sawtooth);
pub const Square = Osc("square", square);
