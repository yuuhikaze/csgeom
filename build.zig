const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "csgeom",
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

    // Add zig-cli dependency
    const zig_cli = b.dependency("cli", .{});
    exe.root_module.addImport("cli", zig_cli.module("cli"));

    // Create repositories module
    const repositories_module = b.addModule("repositories", .{
        .root_source_file = b.path("src/repositories/mod.zig"),
    });
    exe.root_module.addImport("repositories", repositories_module);

    // Create lib module
    const lib_module = b.addModule("lib", .{
        .root_source_file = b.path("src/lib/mod.zig"),
    });
    lib_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));
    lib_module.addImport("repositories", repositories_module);
    exe.root_module.addImport("lib", lib_module);

    // Create renderer module
    const renderer_module = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer.zig"),
    });
    renderer_module.addImport("lib", lib_module);
    renderer_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));
    exe.root_module.addImport("renderer", renderer_module);

    // Create runners module
    const runners_module = b.addModule("runners", .{
        .root_source_file = b.path("src/runners/mod.zig"),
    });
    runners_module.addImport("lib", lib_module);
    runners_module.addImport("repositories", repositories_module);
    runners_module.addImport("renderer", renderer_module);
    exe.root_module.addImport("runners", runners_module);

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

    // Create test step
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib/mod.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib_tests.root_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));
    lib_tests.root_module.addImport("repositories", repositories_module);

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);
}
