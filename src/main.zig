const std = @import("std");
const set = @import("ziglangSet");
const cli = @import("interfaces/cli.zig");
const runners = @import("runners");
const lib = @import("lib");
const geom = lib.geometry;
const repositories = @import("repositories");
const mem = repositories.memory;

pub fn main(init: std.process.Init) !void {
    // Make init state global
    mem.init = init;

    // Create global GPA allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    mem.allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Instantiate interface (CLI)
    try cli.instantiate();
    const config = mem.config;
    switch (config.algorithm) {
        .ConvexHull => switch (config.implementation) {
            .Slow => try runners.convex_hull.runSlow(),
        },
    }
}
