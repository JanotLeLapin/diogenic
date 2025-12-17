const std = @import("std");
const log = std.log.scoped(.compiler);

const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const parser = @import("parser.zig");
const Node = parser.Node;
