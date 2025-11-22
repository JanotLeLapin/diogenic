const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");
const arith = @import("arith.zig");
const math = @import("math.zig");
const osc = @import("osc.zig");
const shaper = @import("shaper.zig");

const STATE_LENGTH = 2048;

pub const Engine = struct {
    stack: std.ArrayList(block.Block),
    stack_allocator: std.mem.Allocator,
    state: [STATE_LENGTH]f32,

    pub fn init(stack_allocator: std.mem.Allocator) !Engine {
        return Engine{
            .stack = try std.ArrayList(block.Block).initCapacity(stack_allocator, 32),
            .stack_allocator = stack_allocator,
            .state = std.mem.zeroes([STATE_LENGTH]f32),
        };
    }

    pub fn eval(self: *Engine, seq: std.ArrayList(instruction.Instruction)) !block.Block {
        for (seq.items) |item| {
            switch (item) {
                .Value => {
                    try self.stack.append(self.stack_allocator, block.Block.initValue(item.Value));
                },
                .Arith => |op| {
                    const left = self.stack.pop().?;
                    const right = self.stack.pop().?;

                    const res = arith.eval(op, left, right);
                    try self.stack.append(self.stack_allocator, res);
                },
                .Math => |op| {
                    const b = self.stack.pop().?;

                    const res = math.eval(op, b);
                    try self.stack.append(self.stack_allocator, res);
                },
                .Osc => |op| {
                    const pm = self.stack.pop().?;
                    const freq = self.stack.pop().?;
                    const acc = &self.state[op.phase_slot];

                    const res = osc.eval(op.t, freq, pm, acc);
                    try self.stack.append(self.stack_allocator, res);
                },
                .Shaper => |op| {
                    const input = self.stack.pop().?;
                    const mix = self.stack.pop().?;

                    const res = shaper.eval(op, mix, input);
                    try self.stack.append(self.stack_allocator, res);
                },
            }
        }

        return self.stack.pop().?;
    }
};
