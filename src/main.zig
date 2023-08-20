const std = @import("std");
const Server = @import("server.zig").Server;
const Handler = @import("handler.zig").Handler;

pub const url = @import("url.zig");

const Error = error{
    expected_ip_in_next_arg,
    expected_port_in_next_arg,
    unknown_arg,
};

pub fn main() !void {
    std.debug.print("Hello, {s}!\n", .{"fsz"});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.next().?;

    var server_ip: []const u8 = "127.0.0.1";
    var server_port: u16 = 5000;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-l")) {
            if (args_iter.next()) |ip_raw| {
                server_ip = ip_raw;
            } else return Error.expected_ip_in_next_arg;
        } else if (std.mem.eql(u8, arg, "-p")) {
            if (args_iter.next()) |port_raw| {
                server_port = try std.fmt.parseInt(u16, port_raw, 10);
            } else return Error.expected_port_in_next_arg;
        } else {
            return Error.unknown_arg;
        }
    }

    var server = try Server(Handler).init(allocator, .{
        .address = try std.net.Address.resolveIp(server_ip, server_port),
    });
    defer server.deinit();

    std.debug.print("Listening on http://{}...\n", .{server.stream_server.listen_address});

    while (true) {
        try server.accept(allocator);
    }
}

test {
    std.testing.refAllDecls(@This());
}
