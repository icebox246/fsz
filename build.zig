const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "fsz",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const fmt_cmd = b.addFmt(.{
        .paths = &.{"src/"},
    });

    const fmt_step = b.step("fmt", "Format codebase");
    fmt_step.dependOn(&fmt_cmd.step);

    const check_fmt_cmd = b.addFmt(.{
        .paths = &.{"src/"},
        .check = true,
    });

    const check_fmt_step = b.step("check-fmt", "Check formatting of codebase");
    check_fmt_step.dependOn(&check_fmt_cmd.step);
}
