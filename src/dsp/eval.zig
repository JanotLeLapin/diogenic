const std = @import("std");

pub fn VecF32(comptime length: u8) type {
    return @Vector(length, f32);
}

pub fn Block(comptime block_length: u32, comptime simd_length: u8) type {
    const Vec = VecF32(simd_length);

    const vecs_per_block = block_length / simd_length;

    return struct {
        vectors: [vecs_per_block]Vec,

        pub fn init() @This() {
            return @This(){ .vectors = std.mem.zeroes([vecs_per_block]Vec) };
        }

        pub fn get(self: *const @This(), idx: u32) f32 {
            return self.vectors[idx / simd_length][idx % simd_length];
        }

        pub fn set(self: *@This(), idx: u32, val: f32) void {
            self.vectors[idx / simd_length][idx % simd_length] = val;
        }
    };
}

pub fn EvalOperators(comptime BlockType: type) type {
    return struct {
        pub fn add(stack: []BlockType, sp: *usize) void {
            const b = stack[sp.* - 1];
            const a = stack[sp.* - 2];

            var result: BlockType = undefined;

            for (a.vectors, b.vectors, 0..) |a_vec, b_vec, i| {
                result.vectors[i] = a_vec + b_vec;
            }

            stack[sp.* - 2] = result;
            sp.* -= 1;
        }
    };
}
