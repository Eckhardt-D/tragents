const std = @import("std");
const WebView = @import("webview").WebView;

pub const Context = struct {
    w: *const WebView,
};

fn parseArgs(args: [:0]const u8) !std.ArrayList([]const u8) {
    const page_allocator = std.heap.page_allocator;
    var args_list = std.ArrayList([]const u8).init(page_allocator);

    var j: usize = 0;

    // Bleh...
    for (args, 0..) |c, i| {
        if (c == 0 or c == ',' or i == args.len - 1) {
            var arg: []const u8 = "";

            for (j..i) |k| {
                switch (args[k]) {
                    ' ' => {},
                    '"' => {},
                    '[' => {},
                    ']' => {},
                    else => {
                        // -1 basically removes ending "
                        // but this assumes all args are just strings
                        // not very reusable
                        arg = args[k .. i - 1];
                        break;
                    },
                }
            }
            try args_list.append(arg);
            j = i + 1;
        }
    }

    return args_list;
}

pub fn require_callback(_: [:0]const u8, args: [:0]const u8, ctx: ?*anyopaque) void {
    const context: *Context = @ptrCast(@alignCast(ctx));

    const args_list = parseArgs(args) catch |err| {
        std.debug.print("failed to parse args: {any}, {any}\n", .{ args, err });
        return;
    };

    const js_file_name = args_list.items[0];

    var file_path = std.heap.page_allocator.alloc(u8, js_file_name.len + "web/".len) catch |err| {
        std.debug.print("failed to allocate file path: {any}\n", .{err});
        return;
    };

    defer std.heap.page_allocator.free(file_path);

    std.mem.copyForwards(u8, file_path[0..], "web/");
    std.mem.copyForwards(u8, file_path["web/".len..], js_file_name);

    const fd = std.fs.cwd().openFile(file_path, .{ .mode = std.fs.File.OpenMode.read_only }) catch |err| {
        std.debug.print("failed to open file: {any}\n", .{err});
        return;
    };

    defer fd.close();

    const max_size: usize = 4 * 1024 * 1024;
    const content: [:0]const u8 = fd.readToEndAllocOptions(std.heap.page_allocator, max_size, null, 512, 0) catch |err| {
        std.debug.print("failed to read file: {any}\n", .{err});
        return;
    };

    std.debug.print("{s}\n", .{content[0..15]});

    std.debug.assert(@TypeOf(context) == *Context);

    const webview = context.w;
    webview.eval(content);
}
