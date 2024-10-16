const std = @import("std");
const Ticks = @import("ticks.zig");
const Gen = @import("generator.zig");
const webui = @import("webui");

fn close(_: *webui.Event) void {
    std.debug.print("Close event\n", .{});
    webui.exit();
}

fn get_ticks(e: *webui.Event) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var generator: Gen.Generator = undefined;

    const seed_tick = Ticks.TickSettings{
        .open = 1.00000,
        .high = 1.00100,
        .low = 0.99900,
        .close = 1.00090,
        .volume = 1000,
    };

    const capacity: usize = 100;

    _ = generator.init(allocator, capacity, seed_tick) catch {
        std.debug.print("Failed to initialize generator\n", .{});
        return;
    };

    defer generator.deinit();

    for (capacity) |_| {
        _ = generator.tick() catch {
            std.debug.print("Failed to generate tick\n", .{});
            return;
        };
    }

    // 100 KiB Buffer
    var json_buffer: [100 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&json_buffer);
    var json = std.ArrayList(u8).init(fba.allocator());

    defer json.deinit();

    std.json.stringify(generator.tick_buffer.items, .{}, json.writer()) catch |err| {
        std.debug.print("Failed to stringify ticks: {}\n", .{err});
        return;
    };

    json.writer().writeByte(0) catch |err| {
        std.debug.print("Failed to write null terminator: {}\n", .{err});
        return;
    };

    const json_string: [:0]const u8 = json.items[0 .. json.items.len - 1 :0];
    e.returnString(json_string);
}

pub fn main() !void {
    var win = webui.newWindow();
    _ = webui.setDefaultRootFolder("web");

    _ = win.bind("close_app", close);
    _ = win.bind("get_ticks", get_ticks);
    _ = win.showBrowser("index.html", .ChromiumBased);

    webui.wait();
    webui.clean();
}
