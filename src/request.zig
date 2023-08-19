const std = @import("std");

pub const Request = struct {
    method: Method,
    url_raw: []u8,
    headers: std.StringHashMap([]u8),
    body_raw: ?[]u8,

    pub const Error = error{
        no_method,
        unknown_method,
        no_url,
        no_version,
    };

    pub const Method = enum {
        get,
        post,
        delete,
        fn fromStr(str: []const u8) !@This() {
            if (std.ascii.eqlIgnoreCase("get", str)) {
                return .get;
            } else if (std.ascii.eqlIgnoreCase("post", str)) {
                return .post;
            } else if (std.ascii.eqlIgnoreCase("delete", str)) {
                return .delete;
            } else {
                return Error.unknown_method;
            }
        }
    };

    pub fn parseStreaming(allocator: std.mem.Allocator, reader: anytype) !@This() {
        var line_buffer = std.ArrayList(u8).init(allocator);
        defer line_buffer.deinit();

        var method: Method = undefined;
        var url_raw: []u8 = undefined;
        var headers = std.StringHashMap([]u8).init(allocator);

        { // parse first line
            try reader.streamUntilDelimiter(line_buffer.writer(), '\n', 1024);
            if (line_buffer.items.len > 0 and line_buffer.items[line_buffer.items.len - 1] == '\r')
                _ = line_buffer.pop(); // lose '\r'

            var words_iter = std.mem.tokenizeScalar(u8, line_buffer.items, ' ');

            const method_temp = words_iter.next() orelse return Error.no_method;
            const url_temp = words_iter.next() orelse return Error.no_url;
            _ = words_iter.next() orelse return Error.no_version;

            method = try Method.fromStr(method_temp);
            url_raw = try allocator.dupe(u8, url_temp);
        }

        { // parse headers
            while (cond: {
                line_buffer.clearAndFree();
                try reader.streamUntilDelimiter(line_buffer.writer(), '\n', 1024);
                if (line_buffer.items.len > 0 and line_buffer.items[line_buffer.items.len - 1] == '\r')
                    _ = line_buffer.pop();
                break :cond line_buffer.items.len != 0;
            }) {
                var values_iter = std.mem.splitSequence(u8, line_buffer.items, ": ");
                const key_temp = values_iter.next().?;
                const val_temp = values_iter.rest();

                var key = try allocator.dupe(u8, key_temp);
                var val = try allocator.dupe(u8, val_temp);

                for (key) |*c|
                    c.* = std.ascii.toLower(c.*);

                try headers.put(key, val);
            }
        }

        var request = @This(){
            .method = method,
            .url_raw = url_raw,
            .headers = headers,
            .body_raw = null,
        };

        if (method == .post) {
            var body_buffer = std.ArrayList(u8).init(allocator);
            try reader.streamUntilDelimiter(body_buffer.writer(), 0, 4 * 1024 * 1024);
            request.body_raw = try body_buffer.toOwnedSlice();
        }
        return request;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.url_raw);
        if (self.body_raw) |b| allocator.free(b);

        var entries_iter = self.headers.iterator();
        while (entries_iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }

        self.headers.deinit();
    }

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print(
            \\Request{{
            \\ .method = {}
            \\ .url_raw = {s}
            \\ .headers = 
            \\
        , .{
            self.method,
            self.url_raw,
        });

        var entries_iter = self.headers.iterator();
        while (entries_iter.next()) |entry| {
            try writer.print("   {s}: {s}\n", .{
                entry.key_ptr.*,
                entry.value_ptr.*,
            });
        }

        if (self.body_raw) |br| {
            try writer.print(
                \\ .body_raw = {s}
                \\
            , .{
                br,
            });
        }

        try writer.print(
            \\}}
        , .{});
    }
};
