const std = @import("std");

const core = @import("diogenic-core");
const CompilerExceptionData = core.compiler.CompilerExceptionData;
const EngineState = core.engine.EngineState;
const Instruction = core.instruction.Instruction;

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

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    if (maybe_instructions) |*instructions| {
        instructions.clearRetainingCapacity();
    } else {
        maybe_instructions = std.ArrayList(Instruction).initCapacity(gpa, 16) catch return -2;
    }

    var mod_map = core.compiler.types.ModuleMap.init(arena.allocator());

    var exceptions = std.ArrayList(core.compiler.types.Exception).initCapacity(gpa, 8) catch return -3;
    defer exceptions.deinit(gpa);

    var env = std.StringHashMap(usize).init(gpa);
    defer env.deinit();

    var state = core.compiler.types.State{
        .map = &mod_map,
        .instr_seq = &maybe_instructions.?,
        .exceptions = &exceptions,
        .env = &env,
        .arena_alloc = arena.allocator(),
        .stack_alloc = gpa,
    };
    const mod = core.compiler.module.resolveImports(&state, "main", src) catch return -4;
    core.compiler.function.expand(&state, mod) catch return -5;
    core.compiler.alpha.expand(&state, mod.root.data.list.getLast()) catch return -6;
    core.compiler.rpn.expand(&state, mod.root.data.list.getLast()) catch return -7;

    if (0 < exceptions.items.len) {
        return -8;
    }

    maybe_engine_state = core.initState(sr, maybe_instructions.?.items, gpa) catch return -9;
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
