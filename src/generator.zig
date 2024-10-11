const std = @import("std");
const Ticks = @import("ticks.zig");

pub const Generator = struct {
    initial_open: f32,
    initial_close: f32,
    initial_high: f32,
    initial_low: f32,
    initial_volume: f32,

    /// The buffer containing historical ticks of size `capacity`
    tick_buffer: std.ArrayList(Ticks.Tick),

    /// The maximum number of ticks to keep in the buffer
    capacity: usize,

    pub fn init(self: *Generator, allocator: std.mem.Allocator, capacity: usize, settings: Ticks.TickSettings) !*Generator {
        self.tick_buffer = std.ArrayList(Ticks.Tick).init(allocator);
        self.capacity = capacity;

        self.initial_open = settings.open;
        self.initial_high = settings.high;
        self.initial_low = settings.low;
        self.initial_close = settings.close;
        self.initial_volume = settings.volume;

        try self.tick_buffer.append(Ticks.Tick.init(.{
            .open = self.initial_open,
            .high = self.initial_high,
            .low = self.initial_low,
            .close = self.initial_close,
            .volume = self.initial_volume,
        }));

        return self;
    }

    pub fn deinit(self: *Generator) void {
        self.tick_buffer.deinit();
    }

    fn incrValue(value: f32, max_percent_change: f32, rand: *std.Random.DefaultPrng) f32 {
        const changeValue = max_percent_change * (@as(f32, @floatFromInt(rand.random().uintLessThan(u8, 2))) + 1);
        return value + (value * changeValue);
    }

    fn decrValue(value: f32, max_percent_change: f32, rand: *std.Random.DefaultPrng) f32 {
        const changeValue = max_percent_change * (@as(f32, @floatFromInt(rand.random().uintLessThan(u8, 2))) + 1);
        return value - (value * changeValue);
    }

    fn calculateNextTick(self: *Generator) Ticks.Tick {
        std.debug.assert(self.tick_buffer.items.len > 0);
        const prev_tick = self.tick_buffer.items[self.tick_buffer.items.len - 1];
        const max_percent_change: f32 = 0.001;
        const max_volume_change: f32 = 0.05;
        const seed: u64 = @intCast(std.time.milliTimestamp());
        var rand = std.Random.DefaultPrng.init(seed);

        const next_open = prev_tick.close;
        const next_high = Generator.incrValue(next_open, max_percent_change, &rand);
        const next_low = Generator.decrValue(next_open, max_percent_change, &rand);

        const next_close = if (rand.random().boolean() == true) blk: {
            const potential_next = Generator.incrValue(next_open, max_percent_change, &rand);
            if (potential_next > next_high) {
                break :blk next_high;
            } else {
                break :blk potential_next;
            }
        } else blk: {
            const potential_next = Generator.decrValue(next_open, max_percent_change, &rand);
            if (potential_next < next_low) {
                break :blk next_low;
            } else {
                break :blk potential_next;
            }
        };

        const next_volume = if (rand.random().boolean() == true) blk: {
            break :blk Generator.incrValue(prev_tick.volume, max_volume_change, &rand);
        } else blk: {
            break :blk Generator.decrValue(prev_tick.volume, max_volume_change, &rand);
        };

        return Ticks.Tick.init(.{
            .open = next_open,
            .high = next_high,
            .low = next_low,
            .close = next_close,
            .volume = next_volume,
        });
    }

    pub fn tick(self: *Generator) !Ticks.Tick {
        // Clamp the buffer
        if (self.tick_buffer.items.len == self.capacity) {
            _ = self.tick_buffer.orderedRemove(0);
        }

        const next = self.calculateNextTick();

        try self.tick_buffer.append(next);
        return next;
    }
};
