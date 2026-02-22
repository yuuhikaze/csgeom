const std = @import("std");
const set = @import("ziglangSet");
const geo = @import("lib/geometry.zig");
const hull = @import("lib/convex_hull.zig");
const rend = @import("lib/renderer.zig");

pub fn main(init: std.process.Init) !void {
    // Create GPA allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Generate 100 random points
    var random_points = try geo.generateRandomPoints(allocator, init.io, 100);
    defer random_points.deinit();

    // Show generated points
    var it_rp = random_points.iterator();
    std.debug.print("Generated {d} unique points:\n", .{random_points.cardinality()});
    while (it_rp.next()) |rnd_point| rnd_point.print();

    // Compute convex hull using slow O(n³) algorithm
    std.debug.print("\nComputing convex hull...\n", .{});
    var convex_hull = try hull.computeSlow(allocator, random_points);
    defer convex_hull.deinit();

    // Show convex hull edges
    var it_ch = convex_hull.iterator();
    std.debug.print("Convex hull edges:\n", .{});
    while (it_ch.next()) |ch_edge| ch_edge.print();

    // Initialize renderer
    var renderer = try rend.Renderer.init();
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.render(random_points, convex_hull);
        rend.sdl.SDL_Delay(16); // ~60 FPS
    }
}
