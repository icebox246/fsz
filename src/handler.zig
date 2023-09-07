const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const url = @import("url.zig");

pub const Handler = struct {
    allocator: std.mem.Allocator,
    root_dir: []const u8,

    const Error = error{ not_found, forbidden };

    pub const Options = struct {
        root_dir: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) !@This() {
        return .{
            .allocator = allocator,
            .root_dir = options.root_dir,
        };
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    pub fn handle(self: *@This(), req: *Request, res: *Response) !void {
        var url_blocks = try url.UrlBlocks.parse(self.allocator, req.url_raw);
        defer url_blocks.deinit(self.allocator);

        (switch (req.method) {
            .get => self.handleGet(req, res, &url_blocks),
            .post => self.handlePost(req, res, &url_blocks),
            .delete => self.handleDelete(req, res, &url_blocks),
        }) catch |e| switch (e) {
            Error.not_found => try self.handleNotFound(req, res, &url_blocks),
            Error.forbidden => try self.handleForbidden(req, res),
            else => return e,
        };
    }

    fn handleGet(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        std.debug.print("Received: GET {}\n", .{url_blocks});

        if (url_blocks.blocks.len == 0) {
            try self.handleGetRoot(req, res);
        } else if (std.mem.eql(u8, url_blocks.blocks[0], "static")) {
            try self.handleGetStatic(req, res, url_blocks);
        } else if (std.mem.eql(u8, url_blocks.blocks[0], "f")) {
            try self.handleGetFiles(req, res, url_blocks);
        } else {
            return Error.not_found;
        }
    }

    fn handlePost(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        std.debug.print("Received: POST {}\n", .{url_blocks});

        if (url_blocks.blocks.len == 0) {
            return Error.forbidden;
        } else if (std.mem.eql(u8, url_blocks.blocks[0], "f")) {
            try self.handlePostFiles(req, res, url_blocks);
        } else {
            return Error.forbidden;
        }
    }

    fn handleDelete(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        std.debug.print("Received: DELETE {}\n", .{url_blocks});

        if (url_blocks.blocks.len == 0) {
            return Error.not_found;
        } else if (std.mem.eql(u8, url_blocks.blocks[0], "f")) {
            try self.handleDeleteFiles(req, res, url_blocks);
        } else {
            return Error.not_found;
        }
    }

    fn handleGetRoot(self: *@This(), req: *Request, res: *Response) !void {
        _ = req;
        _ = self;

        try res.status(200, "OK");
        try res.contentType("text/html");
        try res.data(@embedFile("template/landing.html"));
        try res.finish();
    }

    fn handleGetStatic(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        _ = self;
        _ = req;

        if (url_blocks.blocks.len == 1) return Error.not_found;

        const StaticFileEntry = struct {
            name: []const u8,
            contentType: []const u8,
        };

        const available_static_files = [_]StaticFileEntry{
            .{ .name = "style.css", .contentType = "text/css" },
            .{ .name = "monogram.ttf", .contentType = "font/ttf" },
            .{ .name = "upload.js", .contentType = "text/javascript" },
            .{ .name = "delete.js", .contentType = "text/javascript" },
            .{ .name = "icons_file.webp", .contentType = "image/webp" },
            .{ .name = "icons_folder.webp", .contentType = "image/webp" },
            .{ .name = "icons_trash.webp", .contentType = "image/webp" },
        };

        const requested_resource = url_blocks.blocks[1];

        inline for (available_static_files) |resource| {
            if (std.mem.eql(u8, resource.name, requested_resource)) {
                try res.status(200, "OK");
                try res.contentType(resource.contentType);
                try res.header("cache-control", "public, max-age=3600");
                try res.data(@embedFile("static/" ++ resource.name));
                try res.finish();
                return;
            }
        }

        return Error.not_found;
    }

    fn handleGetFiles(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        _ = req;

        const original_path = url_blocks.blocks[1..];

        const path = try self.sanitizePath(original_path);
        defer self.allocator.free(path);

        var current_dir = try self.openDirByPath(if (path.len > 0) path[0 .. path.len - 1] else path, false);
        defer current_dir.close();

        const resource_name = if (path.len > 0) path[path.len - 1] else ".";

        const stat = current_dir.statFile(resource_name) catch return Error.not_found;

        switch (stat.kind) {
            .file => {
                var file = current_dir.openFile(resource_name, .{}) catch return Error.not_found;
                defer file.close();

                try res.status(200, "OK");
                try res.contentType("text/plain");

                try file.seekFromEnd(0);
                const file_size = try file.getPos();
                try file.seekTo(0);

                {
                    var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 32);
                    defer buffer.deinit();
                    try std.fmt.format(buffer.writer(), "{}", .{file_size});
                    try res.header("Content-Length", buffer.items);
                }

                {
                    var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 256);
                    defer buffer.deinit();
                    try std.fmt.format(buffer.writer(), "inline; filename={s}", .{resource_name});
                    try res.header("Content-Disposition", buffer.items);
                }

                var buffer: [4096]u8 = undefined;
                var bytes_read: usize = undefined;
                while (true) {
                    bytes_read = try file.read(&buffer);
                    try res.data(buffer[0..bytes_read]);
                    if (bytes_read < buffer.len) break;
                }
                try res.finish();
            },
            .directory => {
                var dir = current_dir.openIterableDir(resource_name, .{}) catch return Error.not_found;
                var dir_iter = dir.iterate();
                defer dir.close();

                try res.status(200, "OK");
                try res.contentType("text/html");
                const writer = try res.dataWriter();

                var listing_buffer = std.ArrayList(u8).init(self.allocator);
                defer listing_buffer.deinit();

                const listing_writer = listing_buffer.writer();

                while (try dir_iter.next()) |ent| {
                    var kind_icon: u8 = switch (ent.kind) {
                        .file => 'f',
                        .directory => 'd',
                        else => continue,
                    };
                    try listing_writer.print(@embedFile("template/listing-item.html"), .{
                        .icon = kind_icon,
                        .name = ent.name,
                    });
                }

                try writer.print(@embedFile("template/listing.html"), .{
                    .dirname = resource_name,
                    .listing = listing_buffer.items,
                });

                try res.finish();
            },
            else => return Error.forbidden,
        }
    }

    fn handlePostFiles(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        const original_path = url_blocks.blocks[1..];

        if (original_path.len == 0) return Error.forbidden;
        if (req.body_raw == null) return Error.forbidden;

        const path = try self.sanitizePath(original_path);
        defer self.allocator.free(path);

        var current_dir = try self.openDirByPath(path[0 .. path.len - 1], true);
        defer current_dir.close();

        const resource_name = path[path.len - 1];

        const stat: ?std.fs.File.Stat = current_dir.statFile(resource_name) catch |e|
            switch (e) {
            std.fs.File.OpenError.FileNotFound => null,
            else => return e,
        };

        if (stat) |s|
            if (s.kind != .file) return Error.forbidden;

        var file = current_dir.createFile(resource_name, .{}) catch return Error.not_found;
        defer file.close();

        const Decoder = std.base64.standard.Decoder;

        const decoded_length = Decoder.calcSizeForSlice(req.body_raw.?) catch return Error.forbidden;

        const decoded_buffer = try self.allocator.alloc(u8, decoded_length);
        defer self.allocator.free(decoded_buffer);

        Decoder.decode(decoded_buffer, req.body_raw.?) catch return Error.forbidden;

        try file.writeAll(decoded_buffer);

        try res.status(200, "OK");
        try res.contentType("text/plain");
        try res.data("Successful upload\n");
        try res.finish();
    }

    fn handleDeleteFiles(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        _ = req;

        const original_path = url_blocks.blocks[1..];

        if (original_path.len == 0) return Error.forbidden;

        const path = try self.sanitizePath(original_path);
        defer self.allocator.free(path);

        var current_dir = try self.openDirByPath(path[0 .. path.len - 1], false);
        defer current_dir.close();

        const resource_name = path[path.len - 1];

        const stat = current_dir.statFile(resource_name) catch return Error.not_found;

        switch (stat.kind) {
            .file => current_dir.deleteFile(resource_name) catch return Error.not_found,
            .directory => current_dir.deleteDir(resource_name) catch |e| switch (e) {
                std.fs.Dir.DeleteDirError.DirNotEmpty => return Error.forbidden,
                else => return Error.not_found,
            },
            else => return Error.forbidden,
        }

        try res.status(200, "OK");
        try res.contentType("text/plain");
        try res.data("Successful upload\n");
        try res.finish();
    }

    fn sanitizePath(self: *@This(), original_path: [][]const u8) ![][]const u8 {
        var path_temp = std.ArrayList([]const u8).init(self.allocator);

        for (original_path) |name| {
            if (std.mem.eql(u8, name, ".")) continue;

            if (std.mem.eql(u8, name, "..")) {
                if (path_temp.items.len > 0) _ = path_temp.pop();
                continue;
            }

            try path_temp.append(name);
        }

        const path = try path_temp.toOwnedSlice();
        return path;
    }

    fn openDirByPath(self: *@This(), path: [][]const u8, create_progressively: bool) !std.fs.Dir {
        var current_dir = std.fs.cwd().openDir(self.root_dir, .{}) catch return Error.not_found;

        if (path.len > 0) {
            for (path[0..path.len]) |name| {
                const next_dir_or_error = current_dir.openDir(name, .{});
                if (next_dir_or_error) |next_dir| {
                    current_dir.close();
                    current_dir = next_dir;
                } else |err| {
                    if (create_progressively and err == std.fs.Dir.OpenError.FileNotFound) {
                        try current_dir.makeDir(name);
                        const next_dir = current_dir.openDir(name, .{}) catch return Error.not_found;
                        current_dir.close();
                        current_dir = next_dir;
                    } else return Error.not_found;
                }
            }
        }

        return current_dir;
    }

    fn handleNotFound(self: *@This(), req: *Request, res: *Response, url_blocks: *url.UrlBlocks) !void {
        _ = req;
        _ = self;

        try res.status(404, "Not Found");
        try res.contentType("text/html");
        const writer = try res.dataWriter();
        try writer.print(@embedFile("template/404.html"), .{ .path = url_blocks });
        try res.finish();
    }

    fn handleForbidden(self: *@This(), req: *Request, res: *Response) !void {
        _ = req;
        _ = self;

        try res.status(403, "Forbidden");
        try res.contentType("text/html");
        try res.data("<h1>Forbidden!</h1>");
        try res.finish();
    }
};
