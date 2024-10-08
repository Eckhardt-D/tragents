const std = @import("std");
const Ticks = @import("ticks.zig");
const Gen = @import("generator.zig");
const WebView = @import("webview").WebView;

const Data = struct {
    w: WebView,
    tick_data: struct {
        ticks: *std.ArrayList(Ticks.Tick),
    },
};

//const FPS = 10;
fn cb(x: [:0]const u8, _: [:0]const u8, ctx: ?*anyopaque) void {
    const ctx_data: *Data = @ptrCast(@alignCast(ctx));

    // Todo: size appropriately
    var buf: [4 * 1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var json = std.ArrayList(u8).init(fba.allocator());

    std.json.stringify(ctx_data.tick_data.ticks.items, .{}, json.writer()) catch |err| {
        std.debug.print("Failed to stringify the data: {any}\n", .{err});
        return;
    };

    const ticks: [:0]const u8 = fba.allocator().dupeZ(u8, json.items) catch |err| {
        std.debug.print("Failed to dupe the data: {any}\n", .{err});
        return;
    };

    ctx_data.w.ret(x, 0, ticks);
}

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

    const w = WebView.create(false, null);
    defer w.destroy();

    const fd = try std.fs.cwd().openFile("web/index.html", .{ .mode = std.fs.File.OpenMode.read_only });
    defer fd.close();

    const max_size: usize = 4 * 1024 * 1024;
    const content: [:0]const u8 = try fd.readToEndAllocOptions(heap_allocator, max_size, null, 512, 0);

    for (0..generator.capacity) |_| {
        _ = try generator.tick();
    }

    const data = Data{
        .w = w,
        .tick_data = .{ .ticks = &generator.tick_buffer },
    };

    const ctx: *anyopaque = @ptrCast(@constCast(&data));

    w.setTitle("Zig App");
    w.setSize(1024, 720, .None);
    w.bind("echo", cb, ctx);
    w.setHtml(content);
    w.run();

    //const target_frame_time = 1000 / FPS;
    //var last_tick_time: u64 = @intCast(std.time.milliTimestamp());

    //const fd = try std.fs.cwd().openFile("ticks.csv", .{ .mode = std.fs.File.OpenMode.read_write });
    //defer fd.close();

    //_ = try fd.write("open,high,low,close,volume\n");

    // Main loop
    //while (true) {
    //    const current_tick_time: u64 = @intCast(std.time.milliTimestamp());
    //    const delta_time = current_tick_time - last_tick_time;

    //    if (delta_time < target_frame_time) {
    //        const sleep_time = target_frame_time - delta_time;
    //        std.Thread.sleep(sleep_time * 1000 * 1000);
    //    }

    //    last_tick_time = @intCast(std.time.milliTimestamp());

    //    const tick = try generator.tick();
    //    const outputStr = try std.fmt.allocPrint(heap_allocator, "{d:.6},{d:.6},{d:.6},{d:.6},{d:.1}\n", .{ tick.open, tick.high, tick.low, tick.close, tick.volume });

    //    defer heap_allocator.free(outputStr);

    //    _ = try fd.write(outputStr);
    //}
}
