const std = @import("std");
const Ticks = @import("ticks.zig");
const Gen = @import("generator.zig");
const WebView = @import("webview").WebView;
const FileServer = @import("http.zig").FileServer;

pub fn main() !void {
    const heap_allocator = std.heap.page_allocator;
    var generator: Gen.Generator = undefined;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try FileServer.init(allocator, null, null, null);
    const server_thread = try server.listen();
    defer server_thread.join();

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

    for (0..generator.capacity) |_| {
        _ = try generator.tick();
    }

    w.setTitle("Zig App");
    w.setSize(1024, 720, .None);
    w.navigate("http://127.0.0.1:3000/index.html");
    w.run();
}
