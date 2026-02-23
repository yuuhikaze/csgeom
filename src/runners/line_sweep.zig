const std = @import("std");
const set = @import("ziglangSet");
const lib = @import("lib");
const geom = lib.geometry;
const repositories = @import("repositories");
const mem = repositories.memory;
const rdr = @import("renderer");

pub fn runTopToBottom() !void {
    // Generate 25 random edges (segments)
    var random_edges = try geom.generateRandomEdges(25, mem.allocator, mem.init.io);
    defer random_edges.deinit();

    // Show generated edges
    var it_re = random_edges.iterator();
    std.debug.print("Generated {d} unique edges:\n", .{random_edges.cardinality()});
    while (it_re.next()) |rnd_edge| rnd_edge.print();

    // Compute line sweep TODO

    // Show intersections TODO

    // Initialize renderer
    var renderer = try rdr.Renderer.init("Line Sweep - Top to Bottom O(n log(n))");
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.createArena();
        try renderer.renderEdges(random_edges, .{ 0, 0, 0 });
        // try renderer.renderPoints(intersections);
        renderer.present();
        rdr.sdl.SDL_Delay(16); // ~60 FPS
    }
}
