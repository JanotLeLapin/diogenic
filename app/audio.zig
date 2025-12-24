const std = @import("std");
const log = std.log.scoped(.audio);

const core = @import("diogenic-core");
const EngineState = core.engine.EngineState;
const Instruction = core.instruction.Instruction;

const c = @cImport({
    @cInclude("portaudio.h");
    @cInclude("sndfile.h");
});

pub const Stream = ?*c.PaStream;

pub fn renderWav32(
    filename: []const u8,
    state: *EngineState,
    instructions: []const Instruction,
    block_count: usize,
    buf_allocator: std.mem.Allocator,
) !void {
    var out: [core.engine.BLOCK_LENGTH * 2]f32 = undefined;

    var sfinfo = c.SF_INFO{
        .frames = @intCast(block_count * core.engine.BLOCK_LENGTH),
        .channels = 2,
        .samplerate = @intFromFloat(state.sr),
        .format = c.SF_FORMAT_WAV | c.SF_FORMAT_FLOAT,
    };

    const c_filename = try buf_allocator.dupeZ(u8, filename);
    defer buf_allocator.free(c_filename);

    const f = c.sf_open(c_filename, c.SFM_WRITE, &sfinfo);
    defer _ = c.sf_close(f);

    for (0..block_count) |_| {
        try core.eval(state, instructions);
        for (0..core.engine.BLOCK_LENGTH) |i| {
            out[i * 2] = state.stack[0].get(0, i);
            out[i * 2 + 1] = state.stack[0].get(1, i);
        }
        _ = c.sf_write_float(f, &out, core.engine.BLOCK_LENGTH * 2);
    }
}

inline fn wrapper(code: c_int) !void {
    switch (code) {
        c.paNoError => {},
        else => |_| {
            return error.PaError;
        },
    }
}

pub const CallbackData = struct {
    engine_state: *EngineState,
    instructions: []const Instruction,
};

pub fn callback(
    input_buffer: ?*const anyopaque,
    output_buffer: ?*anyopaque,
    frames_per_buffer: c_ulong,
    time_info: ?*const c.PaStreamCallbackTimeInfo,
    status_flags: c.PaStreamCallbackFlags,
    user_data: ?*anyopaque,
) callconv(.c) i32 {
    const data: *CallbackData = @ptrCast(@alignCast(user_data));
    const out: [*]f32 = @ptrCast(@alignCast(output_buffer));
    _ = input_buffer;
    _ = time_info;
    _ = status_flags;

    core.eval(data.engine_state, data.instructions) catch return 1;
    for (0..frames_per_buffer) |i| {
        out[i * 2] = data.engine_state.stack[0].get(0, i);
        out[i * 2 + 1] = data.engine_state.stack[0].get(1, i);
    }

    return 0;
}

pub fn init() !void {
    try wrapper(c.Pa_Initialize());
}

pub fn openStream(sr: f32, userdata: *CallbackData) !Stream {
    var stream: Stream = undefined;
    try wrapper(c.Pa_OpenDefaultStream(
        &stream,
        0,
        2,
        c.paFloat32,
        sr,
        core.engine.BLOCK_LENGTH,
        &callback,
        @ptrCast(userdata),
    ));
    return stream;
}

pub fn startStream(stream: Stream) !void {
    try wrapper(c.Pa_StartStream(stream));
}

pub fn stopStream(stream: Stream) !void {
    try wrapper(c.Pa_StopStream(stream));
}

pub fn deinit() !void {
    try wrapper(c.Pa_Terminate());
}

pub fn sleep(time: c_long) void {
    c.Pa_Sleep(time);
}
