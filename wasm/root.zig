const std = @import("std");

const core = @import("diogenic-core");
const EngineState = core.engine.EngineState;
const Instruction = core.instruction.Instruction;
const Tokenizer = core.parser.Tokenizer;

const gpa = std.heap.wasm_allocator;

var maybe_instructions: ?std.ArrayList(Instruction) = null;
var maybe_engine_state: ?EngineState = null;

var buffer: [core.engine.BLOCK_LENGTH * 2]f32 = .{0.0} ** (core.engine.BLOCK_LENGTH * 2);

export fn alloc(len: usize) usize {
    const buf = gpa.alloc(u8, len) catch unreachable;
    return @intFromPtr(buf.ptr);
}

export fn compile(src_ptr: [*]u8, src_len: usize, sr: f32) i32 {
    const src = src_ptr[0..src_len];

    var t = Tokenizer{ .src = src };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const root = core.parser.parse(&t, arena.allocator(), gpa) catch return -1;

    if (maybe_instructions) |*instructions| {
        instructions.clearRetainingCapacity();
    } else {
        maybe_instructions = std.ArrayList(Instruction).initCapacity(gpa, 16) catch return -2;
    }
    core.compiler.compile(
        root.data.list.items[0],
        &maybe_instructions.?,
        gpa,
        arena.allocator(),
        gpa,
    ) catch return -2;

    maybe_engine_state = core.initState(sr, maybe_instructions.?.items, gpa) catch return -3;
    return @intCast(maybe_instructions.?.items.len);
}

export fn eval() bool {
    const instructions = maybe_instructions orelse return false;
    if (maybe_engine_state) |*state| {
        core.eval(state, instructions.items) catch return false;
        const b = state.stack[0];
        for (0..core.engine.BLOCK_LENGTH) |i| {
            buffer[i * 2] = b.get(0, i);
            buffer[i * 2 + 1] = b.get(1, i);
        }
        return true;
    }
    return false;
}

export fn getBufPtr() usize {
    return @intFromPtr(&buffer[0]);
}

export fn getBufLen() usize {
    return buffer.len;
}

export fn deinit() void {
    if (maybe_instructions) |*instructions| {
        instructions.deinit(gpa);
        maybe_instructions = null;
    }
}
