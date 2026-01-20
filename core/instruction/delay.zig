const engine = @import("../engine.zig");
const Block = engine.Block;
const CompilerState = engine.CompilerState;
const EngineState = engine.EngineState;
const Vec = engine.Vec;

const meta = @import("./meta.zig");

const parser = @import("../parser.zig");
const Node = parser.Node;

const HISTORY_BITS = 18;
const HISTORY_SIZE = 1 << HISTORY_BITS;
const HISTORY_MASK = HISTORY_SIZE - 1;

const State = struct {
    history: [][2]f32,
    head: usize,
};

pub const Delay = struct {
    pub const name = "delay!";
    pub const description = "delays the input signal";

    pub const args: []const meta.Arg = &.{
        .{ .name = "in", .description = "input signal" },
        .{ .name = "delay", .description = "delay, in seconds" },
    };

    state: *State,

    pub fn compile(d: engine.CompileData) !@This() {
        const state = try d.alloc.create(State);
        state.* = .{
            .history = try d.alloc.alloc([2]f32, HISTORY_SIZE),
            .head = 0,
        };
        return @This(){
            .state = state,
        };
    }

    pub fn eval(self: *const @This(), d: engine.EvalData) void {
        const in = &d.inputs[0];
        const delay = &d.inputs[1];

        const state = self.state;

        for (0..engine.BLOCK_LENGTH) |i| {
            inline for (0..2) |j| {
                state.history[state.head][j] = in.get(j, i);

                const lookback = d.sample_rate * delay.get(j, i);
                const lookback_int: usize = @intFromFloat(lookback);
                const alpha = lookback - @as(f32, @floatFromInt(lookback_int));

                const read_idx = (state.head -% lookback_int) & HISTORY_MASK;
                const next_idx = (state.head -% (lookback_int + 1)) & HISTORY_MASK;

                const read = state.history[read_idx][j];
                const next = state.history[next_idx][j];

                d.output.set(
                    j,
                    @intCast(i),
                    (1 - alpha) * read + alpha * next,
                );
            }
            state.head = (state.head + 1) & HISTORY_MASK;
        }
    }
};
