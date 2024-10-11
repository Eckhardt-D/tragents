const std = @import("std");
const Ticks = @import("ticks.zig");
const Gen = @import("generator.zig");
const webui = @import("webui");

fn close(_: *webui.Event) void {
    std.debug.print("Close event\n", .{});
    webui.exit();
}

pub fn main() !void {
    var win = webui.newWindow();
    _ = webui.setDefaultRootFolder("web");

    _ = win.bind("close_app", close);
    _ = win.showBrowser("index.html", .ChromiumBased);

    webui.wait();
    webui.clean();
}
