const std = @import("std");

pub const CompilerState = struct {
    state_index: usize = 0,
    reg_index: usize = 0,

    env: std.StringHashMap(usize),
};
