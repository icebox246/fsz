const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;

pub fn Server(comptime Handler: type) type {
    return struct {
        stream_server: std.net.StreamServer,
        allocator: std.mem.Allocator,
        handler_opts: Handler.Options,

        pub const ServerOptions = struct {
            address: std.net.Address = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 5000),
            handler_opts: Handler.Options,
        };

        pub fn init(allocator: std.mem.Allocator, options: ServerOptions) !@This() {
            const address = options.address;

            var server = std.net.StreamServer.init(.{
                .reuse_address = true,
                .reuse_port = true,
            });
            try server.listen(address);

            return .{
                .stream_server = server,
                .allocator = allocator,
                .handler_opts = options.handler_opts,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.stream_server.deinit();
        }

        pub fn accept(self: *@This()) !void {
            const conn = try self.stream_server.accept();
            if (!@import("builtin").single_threaded) {
                const thread = try std.Thread.spawn(.{}, handlerWrapper, .{
                    conn,
                    self.allocator,
                    &self.handler_opts,
                });
                thread.detach();
            } else {
                try handlerWrapper(conn, self.allocator, &self.handler_opts);
            }
        }

        fn handlerWrapper(conn: std.net.StreamServer.Connection, parent_allocator: std.mem.Allocator, handler_opts: *const Handler.Options) !void {
            var arena = std.heap.ArenaAllocator.init(parent_allocator);
            defer arena.deinit();
            var allocator = arena.allocator();

            defer conn.stream.close();

            var response = Response.init(conn);

            var handler = try Handler.init(allocator, handler_opts.*);
            defer handler.deinit();

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
                    try response.status(500, "Internal Error");
                    try response.contentType("text/html");
                    var writer = try response.dataWriter();
                    try writer.print("<h1>Internal Error: {}</h1>", .{ex});
                    try response.finish();
                    return;
                },
            };
            defer request.deinit(allocator);

            handler.handle(&request, &response) catch |e|
                std.debug.print("ERROR: Handler crashed with exception: {}\n", .{e});
        }
    };
}
