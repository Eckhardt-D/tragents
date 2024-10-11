const std = @import("std");
const httpz = @import("httpz");

// Created in the spawned thread, not accessed
// in main thread.
const App = struct {
    // TODO: make "web/" configurable from the server instance
    pub fn handle(_: *App, req: *httpz.Request, res: *httpz.Response) void {
        const allocator = std.heap.page_allocator;

        const url = req.url.path;
        const filename = url[1..];

        var full_path = allocator.alloc(u8, "web/".len + filename.len) catch {
            res.status = 500;
            res.body = "500 Internal Server Error";
            return;
        };

        std.mem.copyForwards(u8, full_path[0..], "web/");
        std.mem.copyForwards(u8, full_path["web/".len..], filename);

        var fd = std.fs.cwd().openFile(full_path, .{ .mode = std.fs.File.OpenMode.read_only }) catch {
            res.status = 404;
            res.body = "404 Not Found";
            return;
        };

        defer fd.close();

        const max_size: usize = 4 * 1024 * 1024;

        const content: [:0]const u8 = fd.readToEndAllocOptions(allocator, max_size, null, 512, 0) catch {
            res.status = 500;
            res.body = "500 Internal Server Error";
            return;
        };

        res.status = 200;
        res.body = content;
    }
};

fn spawn_server(host: []const u8, port: u16) !httpz.Server(*App) {
    const allocator = std.heap.page_allocator;
    var app = App{};

    var server = try httpz.Server(*App).init(allocator, .{
        .address = host,
        .port = port,
        .request = .{
            .buffer_size = 10 * 1024,
        },
    }, &app);

    std.debug.print("Listening on http://{s}:{d}\n", .{ host, port });

    _ = try server.listenInNewThread();
    return server;
}

pub const FileServer = struct {
    port: u16 = 3000,
    host: []const u8 = "127.0.0.1",
    root: []const u8 = "web",

    const Self = @This();

    /// Spins up a new thread to listen for incoming requests
    /// to not block the main thread that renders the window.
    pub fn spawn(self: *Self) !httpz.Server(*App) {
        return try spawn_server(self.host, self.port);
    }
};
