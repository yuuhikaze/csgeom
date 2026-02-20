const std = @import("std");
const geo = @import("geometric-lib.zig");
const rend = @import("renderer.zig");

/// Checks if test point is to the left of pq
pub fn test_vector_invalidates_pq(pq: geo.Point, pp_test: geo.Point) bool {
    return geo.calculateCrossProduct(pq, pp_test) < 0;
}

fn compute_convex_hull(allocator: std.mem.Allocator, points: []const geo.Point) ![]geo.Edge {
    // Create allocator
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    // Create candidates list
    var hull_candidates = std.ArrayList(geo.Edge).init(aa);

    // Compute segments that form convex hull O(n^2)
    for (points) |p| {
        for (points) |q| {
            if (p == q) continue;
            const pq_is_valid_candidate = for (points) |p_test| {
                if (p_test == p or p_test == q) continue;
                const pq = geo.create_vector(p, q);
                const pp_test = geo.create_vector(p, p_test);
                if (test_vector_invalidates_pq(pq, pp_test)) break false;
            } else true;
            if (pq_is_valid_candidate) try hull_candidates.append(geo.Edge{ .from = p, .to = q });
        }
    }

    // Return convex hull
    const result = try allocator.dupe(geo.Point, hull_candidates.items);
    return result;
}

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

    // Compute convex hull
    const points_slice = try random_points.keyIterator().toList();
    try compute_convex_hull(allocator, points_slice);

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.renderPoints(random_points);
        rend.sdl.SDL_Delay(16); // ~60 FPS
    }
}
