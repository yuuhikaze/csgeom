const set = @import("ziglangSet");
const std = @import("std");
const lib = @import("lib");
const geom = lib.geometry;
const seg_int = lib.segment_intersection;
const repositories = @import("repositories");
const mem = repositories.memory;
const rdr = @import("renderer");

pub fn runBentleyOttmann() !void {
    // Generate 20 random segments
    var segments = try seg_int.generateRandomSegments(20, mem.allocator, mem.init.io);
    defer segments.deinit(mem.allocator);

    // Show generated segments
    std.debug.print("Generated {d} segments:\n", .{segments.items.len});
    for (segments.items) |*seg| seg.print();

    // Find intersections using Bentley-Ottmann algorithm
    std.debug.print("\nFinding intersections (Bentley-Ottmann)...\n", .{});
    var intersections = try seg_int.findIntersections(mem.allocator, segments.items);
    defer intersections.deinit(mem.allocator);

    // Show intersections
    std.debug.print("Found {d} intersections:\n", .{intersections.items.len});
    for (intersections.items) |*intersection| intersection.print();

    // Initialize renderer
    var renderer = try rdr.Renderer.init("Segment Intersections - Bentley-Ottmann O((n+k) log n)");
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.createArena();
        renderer.renderSegments(segments.items);
        renderer.renderIntersections(intersections.items);
        renderer.present();
        rdr.sdl.SDL_Delay(16); // ~60 FPS
    }
}
