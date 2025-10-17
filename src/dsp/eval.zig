const std = @import("std");

pub fn VecF32(comptime length: u8) type {
    return @Vector(length, f32);
}

pub fn Block(comptime channels: u8, comptime block_length: u32, comptime simd_length: u8) type {
    const Vec = VecF32(simd_length);

    const vecs_per_block = block_length / simd_length;

    return struct {
        channels: [channels][vecs_per_block]Vec,

        pub fn init() @This() {
            return @This(){ .channels = std.mem.zeroes([channels][vecs_per_block]Vec) };
        }

        pub fn get(self: *const @This(), channel: u8, idx: u32) f32 {
            return self.channels[channel][idx / simd_length][idx % simd_length];
        }

        pub fn set(self: *@This(), channel: u8, idx: u32, val: f32) void {
            self.channels[channel][idx / simd_length][idx % simd_length] = val;
        }

        pub fn vecType() type {
            return Vec;
        }
    };
}

pub fn EvalOperators(comptime BlockType: type) type {
    const Vec = BlockType.vecType();
    const Op = fn ([]BlockType, *usize) void;
    const Helpers = struct {
        fn generateBinaryOp(comptime op: fn (Vec, Vec) Vec) Op {
            return struct {
                pub fn generated(stack: []BlockType, sp: *usize) void {
                    const b = &stack[sp.* - 1];
                    const a = &stack[sp.* - 2];

                    var result: BlockType = undefined;

                    for (a.channels, b.channels, 0..) |a_channel, b_channel, i| {
                        for (a_channel, b_channel, 0..) |a_vec, b_vec, j| {
                            result.channels[i][j] = op(a_vec, b_vec);
                        }
                    }

                    stack[sp.* - 2] = result;
                    sp.* -= 1;
                }
            }.generated;
        }
    };
    return struct {
        pub const add = Helpers.generateBinaryOp(struct {
            fn op(a: Vec, b: Vec) Vec {
                return a + b;
            }
        }.op);
        pub const mul = Helpers.generateBinaryOp(struct {
            fn op(a: Vec, b: Vec) Vec {
                return a * b;
            }
        }.op);
        pub const min = Helpers.generateBinaryOp(struct {
            fn op(a: Vec, b: Vec) Vec {
                return @min(a, b);
            }
        }.op);
        pub const max = Helpers.generateBinaryOp(struct {
            fn op(a: Vec, b: Vec) Vec {
                return @max(a, b);
            }
        }.op);
    };
}
