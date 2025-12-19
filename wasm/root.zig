const std = @import("std");

const gpa = std.heap.wasm_allocator;

export fn foo() i32 {
    return 123;
}
