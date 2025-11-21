const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");
const arith = @import("arith.zig");
const math = @import("math.zig");
const osc = @import("osc.zig");
const shaper = @import("shaper.zig");

const STATE_LENGTH = 2048;

pub const Engine = struct {
    state: [STATE_LENGTH]f32,

    pub fn init() Engine {
        return Engine{ .state = std.mem.zeroes([STATE_LENGTH]f32) };
    }

    pub fn eval(self: *Engine, seq: std.ArrayList(instruction.Instruction), stack_allocator: std.mem.Allocator) !block.Block {
        var stack = try std.ArrayList(block.Block).initCapacity(stack_allocator, 32);
        defer stack.deinit(stack_allocator);

        for (seq.items) |item| {
            switch (item) {
                .Value => {
                    try stack.append(stack_allocator, block.Block.initValue(item.Value));
                },
                .Arith => |op| {
                    const left = stack.pop().?;
                    const right = stack.pop().?;

                    const res = arith.eval(op, left, right);
                    try stack.append(stack_allocator, res);
                },
                .Math => |op| {
                    const b = stack.pop().?;

                    const res = math.eval(op, b);
                    try stack.append(stack_allocator, res);
                },
                .Osc => |op| {
                    const pm = stack.pop().?;
                    const freq = stack.pop().?;
                    const acc = &self.state[op.phase_slot];

                    const res = osc.eval(op.t, freq, pm, acc);
                    try stack.append(stack_allocator, res);
                },
                .Shaper => |op| {
                    const input = stack.pop().?;
                    const mix = stack.pop().?;

                    const res = shaper.eval(op, mix, input);
                    try stack.append(stack_allocator, res);
                },
            }
        }

        return stack.pop().?;
    }
};
