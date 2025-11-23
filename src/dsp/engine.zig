const std = @import("std");

const instruction = @import("../instruction.zig");

const block = @import("block.zig");

const arith = @import("arith.zig");
const iir = @import("iir.zig");
const math = @import("math.zig");
const noise = @import("noise.zig");
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

                    const new_block = try self.stack.addOne(self.stack_allocator);
                    arith.eval(op, &left, &right, new_block);
                },
                .Filter => |op| {
                    const in = self.stack.pop().?;
                    const g = self.stack.pop().?;
                    const q = self.stack.pop().?;
                    const fc = self.stack.pop().?;

                    var tmp: [2][2]*f32 = undefined;
                    tmp[0][0] = &self.state[op.tmp_slot];
                    tmp[0][1] = &self.state[op.tmp_slot + 1];
                    tmp[1][0] = &self.state[op.tmp_slot + 2];
                    tmp[1][1] = &self.state[op.tmp_slot + 3];

                    const new_block = try self.stack.addOne(self.stack_allocator);
                    iir.eval(op, tmp, &fc, &q, &g, &in, new_block);
                },
                .Math => |op| {
                    const b = self.stack.pop().?;

                    const new_block = try self.stack.addOne(self.stack_allocator);
                    math.eval(op, &b, new_block);
                },
                .Noise => |op| {
                    const new_block = try self.stack.addOne(self.stack_allocator);
                    noise.eval(op, new_block);
                },
                .Osc => |op| {
                    const pm = self.stack.pop().?;
                    const freq = self.stack.pop().?;
                    const acc = &self.state[op.phase_slot];

                    const new_block = try self.stack.addOne(self.stack_allocator);
                    osc.eval(op.t, &freq, &pm, acc, new_block);
                },
                .Shaper => |op| {
                    const input = self.stack.pop().?;
                    const mix = self.stack.pop().?;

                    const new_block = try self.stack.addOne(self.stack_allocator);
                    shaper.eval(op, &mix, &input, new_block);
                },
            }
        }

        return self.stack.pop().?;
    }
};
