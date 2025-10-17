const std = @import("std");

pub fn Engine(comptime channel_count: u8, comptime block_length: u32, comptime simd_length: u8, comptime stack_size: usize) type {
    const Vec = @Vector(simd_length, f32);

    const vecs_per_block = block_length / simd_length;
    const Block = struct {
        channels: [channel_count][vecs_per_block]Vec,

        pub fn init() @This() {
            return @This(){ .channels = std.mem.zeroes([channel_count][vecs_per_block]Vec) };
        }

        pub fn get(self: *const @This(), channel: u8, idx: u32) f32 {
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
    };

    const BinaryOp = fn (Vec, Vec) Vec;
    const Expr = fn ([]Block, *usize) void;

    return struct {
        sp: usize,
        stack: [stack_size]Block,

        fn generateBinaryExpr(op: BinaryOp) Expr {
            return struct {
                fn res(stack: []Block, sp: *usize) void {
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
                    }.func)(&self.stack, &self.sp),
                    .Mul => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return a * b;
                        }
                    }.func)(&self.stack, &self.sp),
                    .Min => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return @min(a, b);
                        }
                    }.func)(&self.stack, &self.sp),
                    .Max => generateBinaryExpr(struct {
                        fn func(a: Vec, b: Vec) Vec {
                            return @max(a, b);
                        }
                    }.func)(&self.stack, &self.sp),
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
