const std = @import("std");
const httpz = @import("httpz");

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

fn spawn_listen(server: *httpz.Server(*App), host: []const u8, port: u16) !void {
    std.debug.print("Listening on http://{s}:{d}\n", .{ host, port });
    try server.listen();
}

pub const FileServer = struct {
    port: u16 = 3000,
    host: []const u8 = "127.0.0.1",
    root: []const u8 = "web",
    listening: bool = false,
    server: httpz.Server(*App),
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, port: ?u16, host: ?[]const u8, root: ?[]const u8) !FileServer {
        const _port = port orelse 3000;
        const _host = host orelse "127.0.0.1";
        const _root = root orelse "web";

        var app = App{};

        const server = try httpz.Server(*App).init(allocator, .{
            .address = _host,
            .port = _port,
        }, &app);

        return .{
            .port = _port,
            .host = _host,
            .root = _root,
            .server = server,
        };
    }

    /// Spins up a new thread to listen for incoming requests
    /// to not block the main thread that renders the window.
    pub fn listen(self: *Self) !std.Thread {
        self.listening = true;
        std.debug.print("Initializing server, {s} {d}\n", .{ self.host, self.port });
        const thread = try std.Thread.spawn(.{}, spawn_listen, .{ &self.server, self.host, self.port });
        return thread;
    }
};
