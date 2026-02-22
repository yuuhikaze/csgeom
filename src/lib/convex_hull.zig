const std = @import("std");
const set = @import("ziglangSet");
const geom = @import("geometry.zig");

/// Checks if test point is to the left of vector pq
fn isPointToLeft(pq: geom.Point, pp_test: geom.Point) bool {
    return geom.calculateCrossProduct(pq, pp_test) < 0;
}

/// Computes the convex hull using a slow O(n³) algorithm
/// For each pair of points (p, q), checks if all other points are on the left side
/// Returns a Set of edges forming the convex hull
pub fn computeSlow(allocator: std.mem.Allocator, points: set.Set(geom.Point)) !set.Set(geom.Edge) {
    // Create convex hull edge candidates set
    var hull_candidates = set.Set(geom.Edge).init(allocator);

    // Compute segments that form convex hull O(n^2)
    var it_01 = points.iterator();
    while(it_01.next()) |p| {
        var it_02 = points.iterator();
        while (it_02.next()) |q| {
            if (p == q) continue;
            var it_03 = points.iterator();
            const pq_is_valid_candidate = while (it_03.next()) |p_test| {
                if (p_test == p or p_test == q) continue;
                const pq = geom.createVector(p, q);
                const pp_test = geom.createVector(p, p_test);
                if (isPointToLeft(pq, pp_test)) break false;
            } else true;
            if (pq_is_valid_candidate) _ = try hull_candidates.add(geom.Edge{ .from = p.*, .to = q.* });
        }
    }
    return hull_candidates;
}
