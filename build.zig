const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "convex-hull",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Add ziglang-set dependency
    const ziglangSet = b.dependency("ziglangSet", .{});
    exe.root_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));

    // Link SDL3
    exe.root_module.linkSystemLibrary("SDL3", .{});

    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the convex hull visualization");
    run_step.dependOn(&run_cmd.step);
}
