const std = @import("std");

pub fn Engine(comptime channel_count: u8, comptime block_length: u32, comptime simd_length: u8, comptime stack_size: usize) type {
    const Vec = @Vector(simd_length, f32);

    const vecs_per_block = block_length / simd_length;
    const Block = struct {
        channels: [channel_count][vecs_per_block]Vec,

        pub fn init() @This() {
            return @This(){ .channels = std.mem.zeroes([channel_count][vecs_per_block]Vec) };
        }

        pub fn initValue(value: f32) @This() {
            var res = @This(){ .channels = undefined };
            for (res.channels, 0..) |channel, i| {
                for (channel, 0..) |_, j| {
                    res.channels[i][j] = @splat(value);
                }
            }
            return res;
        }

        pub fn get(self: *const @This(), channel: u8, idx: usize) f32 {
            return self.channels[channel][idx / simd_length][idx % simd_length];
        }

        pub fn set(self: *@This(), channel: u8, idx: u32, val: f32) void {
            self.channels[channel][idx / simd_length][idx % simd_length] = val;
        }
    };

    const Operation = union(enum) {
        Push: *const Block,
        Add,
        Mul,
        Min,
        Max,
        Quantize,
        Logn,
        Log2,
        Exp,
        FreqToMidi,
        MidiToFreq,
        SineOsc: usize,
        SquareOsc: usize,
    };

    const BinaryOp = fn (Vec, Vec) Vec;
    const UnaryOp = fn (Vec) Vec;
    const OscOp = fn (*f32, f32) f32;
    const Expr = fn (Operation, []Block, []f32, *usize) void;

    return struct {
        sp: usize,
        stack: [stack_size]Block,
        values: [stack_size]f32,

        fn generateBinaryExpr(op: BinaryOp) Expr {
            return struct {
                fn res(_: Operation, stack: []Block, _: []f32, sp: *usize) void {
                    const b = &stack[sp.* - 1];
                    const a = &stack[sp.* - 2];

                    var result: Block = undefined;

                    for (a.channels, b.channels, 0..) |a_channel, b_channel, i| {
                        for (a_channel, b_channel, 0..) |a_vec, b_vec, j| {
                            result.channels[i][j] = op(a_vec, b_vec);
                        }
                    }

                    stack[sp.* - 2] = result;
                    sp.* -= 1;
                }
            }.res;
        }

        fn generateUnaryExpr(op: UnaryOp) Expr {
            return struct {
                fn res(_: Operation, stack: []Block, _: []f32, sp: *usize) void {
                    const block = &stack[sp.* - 1];

                    var result: Block = undefined;

                    for (block.channels, 0..) |channel, i| {
                        for (channel, 0..) |vec, j| {
                            result.channels[i][j] = op(vec);
                        }
                    }

                    stack[sp.* - 1] = result;
                }
            }.res;
        }

        fn generateOscExpr(op: OscOp, comptime variant: []const u8) Expr {
            return struct {
                fn res(operation: Operation, stack: []Block, values: []f32, sp: *usize) void {
                    const freq = &stack[sp.* - 2];
                    const mod = &stack[sp.* - 1];
                    const previous = &values[@field(operation, variant)];

                    var result: Block = undefined;

                    for (freq.channels, mod.channels, 0..) |freq_channel, mod_channel, i| {
                        for (freq_channel, mod_channel, 0..) |freq_vec, mod_vec, j| {
                            for (0..simd_length) |k| {
                                const increment = 2.0 * std.math.pi * freq_vec[k] / 48000; // TODO: remove hardcoded sr
                                previous.* = @mod(previous.* + increment, 2 * std.math.pi);
                                result.channels[i][j][k] = op(previous, mod_vec[k]);
                            }
                        }
                    }

                    stack[sp.* - 2] = result;
                    sp.* -= 1;
                }
            }.res;
        }

        pub fn run(self: *@This(), instr_set: []const Operation) void {
            for (instr_set) |op| {
                switch (op) {
                    .Push => {
                        self.stack[self.sp] = op.Push.*;
                        self.sp += 1;
                    },
                    .Add => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return a + b;
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Mul => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return a * b;
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Min => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return @min(a, b);
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Max => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return @max(a, b);
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Quantize => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return @round(a * b) / b;
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Logn => generateUnaryExpr(struct {
                        fn func(v: Vec) Vec {
                            return @log(v);
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Log2 => generateUnaryExpr(struct {
                        fn func(v: Vec) Vec {
                            return @log2(v);
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .Exp => generateUnaryExpr(struct {
                        fn func(v: Vec) Vec {
                            return @exp(v);
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .FreqToMidi => generateUnaryExpr(struct {
                        fn func(v: Vec) Vec {
                            return @as(Vec, @splat(69)) + @as(Vec, @splat(12)) * @log2(v / @as(Vec, @splat(440)));
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .MidiToFreq => generateUnaryExpr(struct {
                        fn func(v: Vec) Vec {
                            return @as(Vec, @splat(440)) * @exp2((v - @as(Vec, @splat(69))) / @as(Vec, @splat(12)));
                        }
                    }.func)(op, &self.stack, &self.values, &self.sp),
                    .SineOsc => generateOscExpr(struct {
                        fn func(previous: *f32, mod: f32) f32 {
                            return std.math.sin(previous.* + mod);
                        }
                    }.func, "SineOsc")(op, &self.stack, &self.values, &self.sp),
                    .SquareOsc => generateOscExpr(struct {
                        fn func(previous: *f32, mod: f32) f32 {
                            return if (previous.* + mod < std.math.pi) -1.0 else 1.0;
                        }
                    }.func, "SquareOsc")(op, &self.stack, &self.values, &self.sp),
                }
            }
        }

        pub fn getVecType() type {
            return Vec;
        }

        pub fn getBlockType() type {
            return Block;
        }

        pub fn getOperationType() type {
            return Operation;
        }
    };
}
