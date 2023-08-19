const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;

const default_address = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 5000);

pub fn Server(comptime Handler: type) type {
    return struct {
        stream_server: std.net.StreamServer,
        allocator: std.mem.Allocator,
        handler: Handler,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            const address = default_address;

            var server = std.net.StreamServer.init(.{
                .reuse_address = true,
                .reuse_port = true,
            });
            try server.listen(address);

            var handler = try Handler.init(allocator);

            return .{
                .stream_server = server,
                .allocator = allocator,
                .handler = handler,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.stream_server.deinit();
            self.handler.deinit();
        }

        pub fn accept(self: *@This(), allocator: std.mem.Allocator) !void {
            const conn = try self.stream_server.accept();
            defer conn.stream.close();

            var response = Response.init(conn);

            var reader = conn.stream.reader();
            var request = Request.parseStreaming(allocator, reader) catch |e| switch (e) {
                Request.Error.unknown_method => {
                    try response.status(405, "Method Not Allowed");
                    try response.contentType("text/html");
                    try response.data("<h1>Method Not Allowed!</h1>");
                    try response.finish();
                    return;
                },
                else => |ex| {
                    try response.status(400, "Internal Error");
                    try response.contentType("text/html");
                    var writer = try response.dataWriter();
                    try writer.print("<h1>Internal Error: {}</h1>", .{ex});
                    try response.finish();
                    return;
                },
            };
            defer request.deinit(allocator);

            try self.handler.handle(&request, &response);
        }
    };
}
