const instruction = @import("instruction.zig");

const block = @import("dsp/block.zig");

pub const InterRepr = struct {
    instr_seq: []instruction.Instruction,
};
