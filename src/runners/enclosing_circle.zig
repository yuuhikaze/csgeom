const set = @import("ziglangSet");
const std = @import("std");
const lib = @import("lib");
const geom = lib.geometry;
const repositories = @import("repositories");
const mem = repositories.memory;
const rdr = @import("renderer");

pub fn runWelzl() !void {
    // Generate 100 random points
    var random_points = try geom.generateRandomPoints(100, mem.allocator, mem.init.io);
    defer random_points.deinit();

    // Show generated points
    var it_rp = random_points.iterator();
    std.debug.print("Generated {d} unique points:\n", .{random_points.cardinality()});
    while (it_rp.next()) |rnd_point| rnd_point.print();

    // Compute minimum enclosing circle using Welzl's algorithm
    std.debug.print("\nComputing minimum enclosing circle (Welzl)...\n", .{});
    const circle = try lib.enclosing_circle.computeWelzl(mem.allocator, random_points);

    std.debug.print("Circle center: ({d:.2}, {d:.2}), radius: {d:.2}\n", .{ circle.center.x, circle.center.y, circle.radius });

    // Initialize renderer
    var renderer = try rdr.Renderer.init("Minimum Enclosing Circle - Welzl O(n)");
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.createArena();
        try renderer.renderPoints(random_points);
        renderer.renderCircle(circle.center, circle.radius);
        renderer.present();
        rdr.sdl.SDL_Delay(16); // ~60 FPS
    }
}
