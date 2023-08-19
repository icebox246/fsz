const std = @import("std");

pub fn isUrlAllowed(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or (c == '-') or (c == '_') or (c == '.') or (c == '~');
}

fn predictDecodedLength(encoded_input: []const u8) usize {
    var len: usize = 0;
    var i: usize = 0;
    while (i < encoded_input.len) {
        if (encoded_input[i] == '%') i += 2;
        i += 1;
        len += 1;
    }

    return len;
}

pub fn decode(allocator: std.mem.Allocator, encoded_input: []const u8) ![]u8 {
    const out_len = predictDecodedLength(encoded_input);
    var out = try allocator.alloc(u8, out_len);

    var i: usize = 0;
    var j: usize = 0;
    while (i < encoded_input.len) {
        out[j] = if (encoded_input[i] == '%') parse_percent: {
            defer i += 2;
            break :parse_percent try std.fmt.parseInt(u8, encoded_input[i + 1 .. i + 3], 16);
        } else encoded_input[i];
        i += 1;
        j += 1;
    }

    return out;
}

test "url decoding" {
    {
        const original = "Hello Günter";
        const encoded = "Hello%20G%C3%BCnter";
        const decoded = try decode(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);

        try std.testing.expectEqualStrings(original, decoded);
    }
    {
        const original = "Abc$%^//";
        const encoded = "Abc%24%25%5E%2F%2F";
        const decoded = try decode(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);

        try std.testing.expectEqualStrings(original, decoded);
    }
}

fn predictEncodedLength(encoded_input: []const u8) usize {
    var len = encoded_input.len;

    for (encoded_input) |c| {
        if (!isUrlAllowed(c)) len += 2;
    }

    return len;
}

pub fn encode(allocator: std.mem.Allocator, unencoded_input: []const u8) ![]u8 {
    const out_len = predictEncodedLength(unencoded_input);
    var out = try allocator.alloc(u8, out_len);

    var j: usize = 0;
    for (unencoded_input) |ic| {
        if (isUrlAllowed(ic)) {
            out[j] = ic;
            j += 1;
        } else {
            _ = try std.fmt.bufPrint(out[j .. j + 3], "%{X:0>2}", .{ic});
            j += 3;
        }
    }

    return out;
}

test "url encoding" {
    {
        const original = "Hello Günter";
        const expected = "Hello%20G%C3%BCnter";
        const encoded = try encode(std.testing.allocator, original);
        defer std.testing.allocator.free(encoded);

        try std.testing.expectEqualStrings(expected, encoded);
    }
    {
        const original = "Abc$%^//";
        const expected = "Abc%24%25%5E%2F%2F";
        const encoded = try encode(std.testing.allocator, original);
        defer std.testing.allocator.free(encoded);

        try std.testing.expectEqualStrings(expected, encoded);
    }
}

test "url encode and decode" {
    {
        const original = "Hello Günter";
        const encoded = try encode(std.testing.allocator, original);
        defer std.testing.allocator.free(encoded);
        const decoded = try decode(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);

        try std.testing.expectEqualStrings(original, decoded);
    }
    {
        const original = "Abc$%^//";
        const encoded = try encode(std.testing.allocator, original);
        defer std.testing.allocator.free(encoded);
        const decoded = try decode(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);

        try std.testing.expectEqualStrings(original, decoded);
    }
}

pub const UrlBlocks = struct {
    blocks: [][]u8,

    pub fn parse(allocator: std.mem.Allocator, url: []const u8) !@This() {
        var raw_blocks_iter = std.mem.tokenizeScalar(u8, url, '/');

        var blocks_count: usize = 0;
        while (raw_blocks_iter.next()) |_|
            blocks_count += 1;

        var blocks = try allocator.alloc([]u8, blocks_count);

        raw_blocks_iter.reset();

        var i: usize = 0;
        while (raw_blocks_iter.next()) |raw_block| : (i += 1) {
            blocks[i] = try decode(allocator, raw_block);
        }

        return .{ .blocks = blocks };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.blocks) |block| {
            allocator.free(block);
        }
        allocator.free(self.blocks);
    }

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        if (self.blocks.len == 0) {
            try writer.writeAll("/");
            return;
        }

        for (self.blocks) |block| {
            try writer.print("/{[quotes]s}{[content]s}{[quotes]s}", .{ .content = block, .quotes = for (block) |c| {
                if (!isUrlAllowed(c)) break "`";
            } else "" });
        }
    }
};

test "url blocks parsing" {
    const url = "/foo/bar%2F/foo%20bar.html";
    var url_blocks = try UrlBlocks.parse(std.testing.allocator, url);
    defer url_blocks.deinit(std.testing.allocator);

    const expected = [_][]const u8{ "foo", "bar/", "foo bar.html" };

    for (url_blocks.blocks, expected) |b, e| {
        try std.testing.expectEqualStrings(e, b);
    }
}

test "url blocks formatting" {
    const url = "/foo/bar%2F/foo%20bar.html";
    var url_blocks = try UrlBlocks.parse(std.testing.allocator, url);
    defer url_blocks.deinit(std.testing.allocator);

    var formatted_url = try std.fmt.allocPrint(std.testing.allocator, "{}", .{url_blocks});
    defer std.testing.allocator.free(formatted_url);

    const expected = "/foo/`bar/`/`foo bar.html`";

    try std.testing.expectEqualStrings(expected, formatted_url);
}

test "url blocks formatting root url" {
    const url = "/";
    var url_blocks = try UrlBlocks.parse(std.testing.allocator, url);
    defer url_blocks.deinit(std.testing.allocator);

    var formatted_url = try std.fmt.allocPrint(std.testing.allocator, "{}", .{url_blocks});
    defer std.testing.allocator.free(formatted_url);

    const expected = "/";

    try std.testing.expectEqualStrings(expected, formatted_url);
}
