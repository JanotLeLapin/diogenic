const std = @import("std");

pub const SIMD_LENGTH = 8;
pub const BLOCK_LENGTH = 128;

const VECS_PER_BLOCK = BLOCK_LENGTH / SIMD_LENGTH;

pub const Vec = @Vector(SIMD_LENGTH, f32);
pub const Block = struct {
    channels: [2][VECS_PER_BLOCK]Vec,

    pub fn init() Block {
        return Block{ .channels = std.mem.zeroes([2][VECS_PER_BLOCK]Vec) };
    }

    pub fn initValue(value: f32) Block {
        var res = Block{ .channels = undefined };
        for (res.channels, 0..) |channel, i| {
            for (channel, 0..) |_, j| {
                res.channels[i][j] = @splat(value);
            }
        }
        return res;
    }

    pub fn get(self: *const Block, channel: u8, idx: usize) f32 {
        return self.channels[channel][idx / SIMD_LENGTH][idx % SIMD_LENGTH];
    }

    pub fn set(self: *Block, channel: u8, idx: u32, val: f32) void {
        self.channels[channel][idx / SIMD_LENGTH][idx % SIMD_LENGTH] = val;
    }
};

pub const EngineState = struct {
    sr: f32,
    stack: []Block,
    reg: []Block,
    state: []f32,

    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, sr: f32) !EngineState {
        const state = try alloc.alloc(f32, 4096);
        @memset(state, 0.0);

        return .{
            .sr = sr,
            .stack = try alloc.alloc(Block, 65536),
            .reg = try alloc.alloc(Block, 256),
            .state = state,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *EngineState) void {
        self.alloc.free(self.stack);
        self.alloc.free(self.reg);
        self.alloc.free(self.state);
    }
};

pub const CompilerState = struct {
    state_index: usize = 0,
    reg_index: usize = 0,

    env: std.StringHashMap(usize),
};
