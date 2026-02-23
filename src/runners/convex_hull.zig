const std = @import("std");
const set = @import("ziglangSet");
const lib = @import("lib");
const geom = lib.geometry;
const repositories = @import("repositories");
const mem = repositories.memory;
const rdr = @import("renderer");

pub fn runSlow() !void {
    // Generate 100 random points
    var random_points = try geom.generateRandomPoints(100, mem.allocator, mem.init.io);
    defer random_points.deinit();

    // Show generated points
    var it_rp = random_points.iterator();
    std.debug.print("Generated {d} unique points:\n", .{random_points.cardinality()});
    while (it_rp.next()) |rnd_point| rnd_point.print();

    // Compute convex hull using slow O(n³) algorithm
    std.debug.print("\nComputing convex hull...\n", .{});
    var convex_hull = try lib.convex_hull.computeSlow(mem.allocator, random_points);
    defer convex_hull.deinit();

    // Show convex hull edges
    var it_ch = convex_hull.iterator();
    std.debug.print("Computed convex hull edges:\n", .{});
    while (it_ch.next()) |ch_edge| ch_edge.print();

    // Initialize renderer
    var renderer = try rdr.Renderer.init("Convex Hull - Slow O(n³)");
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.createArena();
        try renderer.renderPoints(random_points, .{0, 0, 0});
        try renderer.renderEdges(convex_hull, .{255, 0, 0});
        renderer.present();
        rdr.sdl.SDL_Delay(16); // ~60 FPS
    }
}
