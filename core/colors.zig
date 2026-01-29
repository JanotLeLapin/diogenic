const Error = @import("std").Io.Writer.Error;

pub const red = "\x1b[31m";
pub const green = "\x1b[32m";
pub const magenta = "\x1b[35m";
pub const reset = "\x1b[0m";

const Fn = fn (anytype) Error!usize;

fn builder(comptime color: []const u8) Fn {
    return struct {
        fn f(writer: anytype) Error!usize {
            return writer.write(color);
        }
    }.f;
}

pub const setRed = builder(red);
pub const setGreen = builder(green);
pub const setMagenta = builder(magenta);
pub const setReset = builder(reset);
