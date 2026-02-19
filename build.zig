const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "slow-convex-hull",
        .root_source_file = b.path("slow-convex-hull.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link SDL3
    exe.linkSystemLibrary("SDL3");
    exe.linkLibC();

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
