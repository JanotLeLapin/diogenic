const std = @import("std");
const log = std.log.scoped(.audio);

const core = @import("diogenic-core");
const EngineState = core.engine.EngineState;
const Instruction = core.instruction.Instruction;

const portaudio = @cImport({
    @cInclude("portaudio.h");
});

pub const Stream = ?*portaudio.PaStream;

inline fn wrapper(code: c_int) !void {
    switch (code) {
        portaudio.paNoError => {},
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
    time_info: ?*const portaudio.PaStreamCallbackTimeInfo,
    status_flags: portaudio.PaStreamCallbackFlags,
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
    try wrapper(portaudio.Pa_Initialize());
}

pub fn openStream(sr: f32, userdata: *CallbackData) !Stream {
    var stream: Stream = undefined;
    try wrapper(portaudio.Pa_OpenDefaultStream(
        &stream,
        0,
        2,
        portaudio.paFloat32,
        sr,
        core.engine.BLOCK_LENGTH,
        &callback,
        @ptrCast(userdata),
    ));
    return stream;
}

pub fn startStream(stream: Stream) !void {
    try wrapper(portaudio.Pa_StartStream(stream));
}

pub fn stopStream(stream: Stream) !void {
    try wrapper(portaudio.Pa_StopStream(stream));
}

pub fn deinit() !void {
    try wrapper(portaudio.Pa_Terminate());
}

pub fn sleep(time: c_long) void {
    portaudio.Pa_Sleep(time);
}
