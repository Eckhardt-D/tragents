const std = @import("std");
const Ticks = @import("ticks.zig");
const Gen = @import("generator.zig");

const FPS = 10;

pub fn main() !void {
    const heap_allocator = std.heap.page_allocator;
    var generator: Gen.Generator = undefined;

    _ = generator.init(heap_allocator, 100, .{
        .open = 1.0123,
        .high = 1.0143,
        .low = 1.0118,
        .close = 1.0132,
        .volume = 1000,
    }) catch |err| {
        std.debug.print("Failed to initialize the generator, out of memory?", .{});
        return err;
    };

    defer generator.deinit();

    const target_frame_time = 1000 / FPS;
    var last_tick_time: u64 = @intCast(std.time.milliTimestamp());

    const fd = try std.fs.cwd().openFile("ticks.csv", .{ .mode = std.fs.File.OpenMode.read_write });
    defer fd.close();

    _ = try fd.write("open,high,low,close,volume\n");

    // Main loop
    while (true) {
        const current_tick_time: u64 = @intCast(std.time.milliTimestamp());
        const delta_time = current_tick_time - last_tick_time;

        if (delta_time < target_frame_time) {
            const sleep_time = target_frame_time - delta_time;
            std.Thread.sleep(sleep_time * 1000 * 1000);
        }

        last_tick_time = @intCast(std.time.milliTimestamp());

        const tick = try generator.tick();
        const outputStr = try std.fmt.allocPrint(heap_allocator, "{d:.6},{d:.6},{d:.6},{d:.6},{d:.1}\n", .{ tick.open, tick.high, tick.low, tick.close, tick.volume });

        defer heap_allocator.free(outputStr);

        _ = try fd.write(outputStr);
    }
}
