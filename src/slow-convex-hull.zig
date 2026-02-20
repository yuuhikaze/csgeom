const std = @import("std");
const set = @import("ziglangSet");
const geo = @import("geometric-lib.zig");
const rend = @import("renderer.zig");

/// Checks if test point is to the left of pq
pub fn test_vector_invalidates_pq(pq: geo.Point, pp_test: geo.Point) bool {
    return geo.calculateCrossProduct(pq, pp_test) < 0;
}

fn compute_convex_hull(allocator: std.mem.Allocator, points: set.Set(geo.Point)) !set.Set(geo.Edge) {
    // Create convex hull edge candidates set
    var hull_candidates = set.Set(geo.Edge).init(allocator);

    // Compute segments that form convex hull O(n^2)
    var it_01 = points.iterator();
    while(it_01.next()) |p| {
        var it_02 = points.iterator();
        while (it_02.next()) |q| {
            if (p == q) continue;
            var it_03 = points.iterator();
            const pq_is_valid_candidate = while (it_03.next()) |p_test| {
                if (p_test == p or p_test == q) continue;
                const pq = geo.create_vector(p, q);
                const pp_test = geo.create_vector(p, p_test);
                if (test_vector_invalidates_pq(pq, pp_test)) break false;
            } else true;
            if (pq_is_valid_candidate) _ = try hull_candidates.add(geo.Edge{ .from = p.*, .to = q.* });
        }
    }
    return hull_candidates;
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
    var it_rp = random_points.iterator();
    std.debug.print("Generated {d} unique points:\n", .{random_points.cardinality()});
    while (it_rp.next()) |rnd_point| rnd_point.print();

    // Initialize renderer
    var renderer = try rend.Renderer.init();
    defer renderer.deinit();

    // Compute convex hull
    std.debug.print("\n", .{});
    const convex_hull = try compute_convex_hull(allocator, random_points);
    var it_ch = convex_hull.iterator();
    while (it_ch.next()) |ch_edge| ch_edge.print();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.renderPoints(random_points);
        rend.sdl.SDL_Delay(16); // ~60 FPS
    }
}
