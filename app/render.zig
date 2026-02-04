const std = @import("std");

const log = std.log.scoped(.render);

const core = @import("diogenic-core");
const Instr = core.instruction.Instruction;

const compiler = core.compiler;
const Exception = compiler.types.Exception;
const ModuleMap = compiler.types.ModuleMap;
const State = compiler.types.State;

const audio = @import("audio.zig");

pub fn render(
    gpa: std.mem.Allocator,
    path: []const u8,
    sample_rate: f32,
    seconds: f32,
) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const src = try file.readToEndAlloc(gpa, 10 * 1024 * 1024);
    defer gpa.free(src);

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var instr_arena = std.heap.ArenaAllocator.init(gpa);
    defer instr_arena.deinit();

    var map = ModuleMap.init(arena.allocator());
    defer map.deinit();

    var instr_seq = try std.ArrayList(Instr).initCapacity(gpa, 16);
    defer instr_seq.deinit(gpa);

    var exceptions = try std.ArrayList(Exception).initCapacity(gpa, 16);
    defer exceptions.deinit(gpa);

    var env = std.StringHashMap(usize).init(arena.allocator());
    defer env.deinit();

    var state = core.compiler.types.State{
        .map = &map,
        .instr_seq = &instr_seq,
        .exceptions = &exceptions,
        .env = &env,
        .arena_alloc = arena.allocator(),
        .stack_alloc = gpa,
        .instr_alloc = instr_arena.allocator(),
    };

    log.info("compiling {s}", .{path});

    const mod = try core.compiler.module.resolveImports(&state, path, src);
    try core.compiler.function.expand(&state, mod);

    const exprNode = mod.root.data.list.getLast();
    try core.compileExpr(&state, exprNode);

    if (0 < exceptions.items.len) {
        try core.printExceptions(&state, mod, exceptions.items);
        return;
    }

    var e = try core.initState(sample_rate, instr_seq.items, gpa);
    defer e.deinit();

    const sample_count = sample_rate * seconds;
    const block_count = sample_count / @as(f32, @floatFromInt(core.engine.BLOCK_LENGTH));

    log.info("rendering to out.wav", .{});

    const start = std.time.nanoTimestamp();
    try audio.renderWav32(
        "out.wav",
        &e,
        instr_seq.items,
        @intFromFloat(block_count),
        gpa,
    );
    const end = std.time.nanoTimestamp();
    const time = end - start;

    log.info("done, took {d}ms", .{@divFloor(time, 1_000_000)});
}
