const std = @import("std");

pub const Response = struct {
    conn: std.net.StreamServer.Connection,
    bw: BufferedWriter,
    state: ResponseState,

    pub const BufferedWriter = std.io.BufferedWriter(4096, std.net.Stream.Writer);

    pub const ResponseState = enum {
        beginning,
        sending_headers,
        sending_data,
    };

    pub const ResponseError = error{
        not_at_beggining,
        not_at_sending_headers,
    };

    pub fn init(conn: std.net.StreamServer.Connection) @This() {
        return .{
            .conn = conn,
            .bw = std.io.bufferedWriter(conn.stream.writer()),
            .state = .beginning,
        };
    }

    pub fn status(self: *@This(), code: u32, message: []const u8) !void {
        if (self.state != .beginning) return ResponseError.not_at_beggining;

        try self.bw.writer().print("HTTP/1.1 {} {s}\r\n", .{
            code,
            message,
        });

        self.state = .sending_headers;

        try self.header("Server", "fsz");
    }

    pub fn header(self: *@This(), h: []const u8, v: []const u8) !void {
        if (self.state != .sending_headers) return ResponseError.not_at_sending_headers;
        try self.bw.writer().print("{s}: {s}\r\n", .{ h, v });
    }

    pub fn contentType(self: *@This(), contentT: []const u8) !void {
        try self.header("Content-Type", contentT);
    }

    pub fn data(self: *@This(), d: []const u8) !void {
        if (self.state != .sending_headers and self.state != .sending_data) {
            return ResponseError.not_at_sending_headers;
        }
        if (self.state != .sending_data) try self.bw.writer().writeAll("\r\n");
        try self.bw.writer().writeAll(d);
        self.state = .sending_data;
    }

    pub fn dataWriter(self: *@This()) !BufferedWriter.Writer {
        if (self.state != .sending_headers and self.state != .sending_data) {
            return ResponseError.not_at_sending_headers;
        }
        if (self.state != .sending_data) try self.bw.writer().writeAll("\r\n");
        self.state = .sending_data;
        return self.bw.writer();
    }

    pub fn finish(self: *@This()) !void {
        try self.bw.flush();
    }
};
