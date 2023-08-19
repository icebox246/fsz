const std = @import("std");
const Server = @import("server.zig").Server;
const Handler = @import("handler.zig").Handler;
const url = @import("url.zig");

pub fn main() !void {
    std.debug.print("Hello, {s}!\n", .{"fsz"});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    var server = try Server(Handler).init(allocator);
    defer server.deinit();

    std.debug.print("Listening on http://{}...\n", .{server.stream_server.listen_address});

    while (true) {
        try server.accept(allocator);
    }
}
