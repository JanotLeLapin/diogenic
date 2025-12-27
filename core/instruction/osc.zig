const std = @import("std");

const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

pub const Op = fn (f32) f32;
pub const OpVec = fn (Vec) Vec;

pub const Random = struct {
    pub const name = "random!";
    pub const description = "random interpolated instantaneous wave amplitude";

    pub const state_count = 5;

    pub const args: []const meta.Arg = &.{
        .{ .name = "freq", .description = "random value refresh rate, in Hz" },
    };

    pub fn compile(_: engine.CompileData) !@This() {
        return @This(){};
    }

    pub fn eval(_: *const @This(), d: engine.EvalData) void {
        const freq = &d.inputs[0];
        const prev_amp = &d.state[0];
        const next_amp = &d.state[1];
        const c = &d.state[2];

        const inv_sr = 1.0 / d.sample_rate;

        for (freq.channels, &d.output.channels) |freq_chan, *out_chan| {
            for (freq_chan, out_chan) |freq_vec, *out_vec| {
                for (0..engine.SIMD_LENGTH) |i| {
                    c.* += inv_sr * freq_vec[i];
                    if (c.* > 1.0) {
                        const seed: u64 = (@as(u64, @intCast(@as(u32, @bitCast(d.state[3]))))) << 8 | @as(u32, @bitCast(d.state[4]));
                        var prng = std.Random.DefaultPrng.init(seed);
                        var rand = prng.random();

                        const next_seed: u64 = rand.int(u64);
                        d.state[3] = @bitCast(@as(u32, @truncate(next_seed >> 32)));
                        d.state[4] = @bitCast(@as(u32, @truncate(next_seed)));

                        c.* = c.* - @floor(c.*);
                        prev_amp.* = next_amp.*;
                        next_amp.* = rand.float(f32) * 2.0 - 1.0;
                    }

                    out_vec[i] = prev_amp.* * (1.0 - c.*) + next_amp.* * c.*;
                }
            }
        }
    }
};

pub fn Osc(
    comptime label: [:0]const u8,
    comptime op_name: []const u8,
    comptime op_vec: OpVec,
) type {
    return struct {
        pub const name = label;
        pub const description = "instantaneous " ++ op_name ++ " wave amplitude";

        pub const state_count = 1;

        pub const args: []const meta.Arg = &.{
            .{ .name = "freq", .description = "target frequency" },
            .{ .name = "pm", .description = "instantaneous phase offset", .default = 0.0 },
        };

        static_freq: ?f32,

        pub fn compile(d: engine.CompileData) !@This() {
            return @This(){
                .static_freq = switch (d.node.data.list.items[1].data) {
                    .num => |num| num,
                    else => null,
                },
            };
        }

        inline fn evalDynamic(
            sr: f32,
            freq: *const Block,
            pm: *const Block,
            phase: *f32,
            out: *Block,
        ) void {
            var acc: f32 = 0.0;
            for (freq.channels, pm.channels, 0..) |freq_chan, pm_chan, i| {
                acc = phase.*;
                for (freq_chan, pm_chan, 0..) |freq_vec, pm_vec, j| {
                    const inc_vec = freq_vec / @as(Vec, @splat(sr));
                    var acc_vec: Vec = undefined;
                    inline for (0..engine.SIMD_LENGTH) |k| {
                        acc_vec[k] = acc;
                        acc += inc_vec[k];
                        acc -= @floor(acc);
                    }
                    const radians_vec = @as(Vec, @splat(2 * std.math.pi)) * acc_vec;
                    out.channels[i][j] = op_vec(radians_vec + pm_vec);
                }
            }

            phase.* = acc;
        }

        inline fn evalStatic(
            sr: f32,
            freq: f32,
            pm: *const Block,
            phase: *f32,
            out: *Block,
        ) void {
            const inc = freq / sr;

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

        pub fn eval(self: *const @This(), d: engine.EvalData) void {
            const freq = &d.inputs[0];
            const pm = &d.inputs[1];
            const phase = &d.state[0];

            if (self.static_freq) |v| {
                evalStatic(d.sample_rate, v, pm, phase, d.output);
            } else {
                evalDynamic(d.sample_rate, freq, pm, phase, d.output);
            }
        }
    };
}

fn sine(p: Vec) Vec {
    return @sin(p);
}

fn sawtooth(p: Vec) Vec {
    return p / @as(Vec, @splat(std.math.pi)) - @as(Vec, @splat(1.0));
}

fn square(p: Vec) Vec {
    return @floor(p / @as(Vec, @splat(std.math.pi))) * @as(Vec, @splat(2.0)) - @as(Vec, @splat(1.0));
}

fn triangle(p: Vec) Vec {
    const mask = p < @as(Vec, @splat(std.math.pi));
    return @select(
        f32,
        mask,
        @as(Vec, @splat(2.0 / std.math.pi)) * p - @as(Vec, @splat(1.0)),
        @as(Vec, @splat(3.0)) - @as(Vec, @splat(2.0 / std.math.pi)) * p,
    );
}

pub const Sine = Osc("sine!", "sine", sine);
pub const Sawtooth = Osc("sawtooth!", "saw tooth", sawtooth);
pub const Square = Osc("square!", "square", square);
pub const Triangle = Osc("triangle!", "triangle", triangle);
