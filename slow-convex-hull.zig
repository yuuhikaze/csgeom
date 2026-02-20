const std = @import("std");
const geo = @import("geometric-lib.zig");
const rend = @import("renderer.zig");

pub fn is_point_to_the_right(vec_pq: geo.Point, vec_test: geo.Point) bool {
    return geo.calculateCrossProduct(vec_pq, vec_test) < 0;
}

fn compute_convex_hull(allocator: std.mem.Allocator, points: []const geo.Point) ![]geo.Point {
    // Create allocator
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    // Create candidates list
    var hull_candidates = std.ArrayList(geo.Point).init(aa);
    var ordered_hull_candidates = std.ArrayList(geo.Point).init(aa);

    // Compute segments that form convex hull O(n^2)
    for (points) |vec_pq| {
        for (points, 0..) |vec_test, i| {
            if (vec_test.x == vec_pq.x or vec_test.y == vec_pq.y) continue;
            if (!is_point_to_the_right(vec_pq, vec_test) and i == points.len - 1)
                try hull_candidates.append(vec_pq);
        }
    }

    // Order segments to form a path
    var from = hull_candidates[0];
    try ordered_hull_candidates.append(from);
    for (0..hull_candidates.len) |_| {
        for (hull_candidates) |to| {
            if (from.y == to.x) {
                try ordered_hull_candidates.append(to);
                from = to;
            }
        }
    }

    // Return convex hull
    const result = try allocator.dupe(geo.Point, ordered_hull_candidates.items);
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
