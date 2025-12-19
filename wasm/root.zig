const std = @import("std");

const core = @import("diogenic-core");
const CompilerState = core.engine.CompilerState;
const Instruction = core.instruction.Instruction;
const Tokenizer = core.parser.Tokenizer;

const gpa = std.heap.wasm_allocator;

var maybe_instructions: ?std.ArrayList(Instruction) = null;

export fn alloc(len: usize) usize {
    const buf = gpa.alloc(u8, len) catch unreachable;
    return @intFromPtr(buf.ptr);
}

export fn compile(src_ptr: [*]u8, src_len: usize) i32 {
    const src = src_ptr[0..src_len];

    var t = Tokenizer{ .src = src };
    var cs = CompilerState{
        .env = std.StringHashMap(usize).init(gpa),
    };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const root = core.parser.parse(&t, arena.allocator(), gpa) catch return -1;

    if (maybe_instructions) |*instructions| {
        instructions.clearRetainingCapacity();
    } else {
        maybe_instructions = std.ArrayList(Instruction).initCapacity(gpa, 16) catch return -2;
    }
    core.compiler.compile(
        &cs,
        root.data.list.items[0],
        &maybe_instructions.?,
        gpa,
    ) catch return -2;

    return @intCast(maybe_instructions.?.items.len);
}

export fn deinit() void {
    if (maybe_instructions) |*instructions| {
        instructions.deinit(gpa);
        maybe_instructions = null;
    }
}
