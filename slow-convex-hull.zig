const std = @import("std");
const geo = @import("geometric-lib.zig");
const rend = @import("renderer.zig");

pub fn main(init: std.process.Init) !void {
    _ = init;
    // Create GPA allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Generate 100 random points
    var random_points = try geo.generateRandomPoints(allocator, 100);
    defer random_points.deinit();

    // Show results
    var it = random_points.keyIterator();
    std.debug.print("Generated {d} unique points:\n", .{random_points.count()});
    while (it.next()) |p| {
        std.debug.print("({d}, {d})\n", .{ p.x, p.y });
    }

    // Initialize renderer
    var renderer = try rend.Renderer.init();
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.renderPoints(random_points);
        rend.sdl.SDL_Delay(16); // ~60 FPS
    }

    // Compute convex hull (slow) I'll do this
    // Render points + convex hull
}
