const std = @import("std");
const set = @import("ziglangSet");
const geom = @import("geometry.zig");

/// Checks if test point is to the left of vector pq
fn isPointToLeft(pq: geom.Point, pp_test: geom.Point) bool {
    return geom.calculateCrossProduct(pq, pp_test) < 0;
}

/// Returns the cross product of vectors (o->a) and (o->b)
/// Positive = counter-clockwise turn, Negative = clockwise turn, Zero = collinear
fn crossProduct(o: geom.Point, a: geom.Point, b: geom.Point) i64 {
    const oa_x: i64 = @as(i64, a.x) - @as(i64, o.x);
    const oa_y: i64 = @as(i64, a.y) - @as(i64, o.y);
    const ob_x: i64 = @as(i64, b.x) - @as(i64, o.x);
    const ob_y: i64 = @as(i64, b.y) - @as(i64, o.y);
    return oa_x * ob_y - oa_y * ob_x;
}

/// Squared distance between two points
fn distanceSquared(a: geom.Point, b: geom.Point) i64 {
    const dx: i64 = @as(i64, b.x) - @as(i64, a.x);
    const dy: i64 = @as(i64, b.y) - @as(i64, a.y);
    return dx * dx + dy * dy;
}

/// Computes convex hull using Graham Scan O(n log n)
/// Returns a Set of edges forming the convex hull
pub fn computeGraham(allocator: std.mem.Allocator, points: set.Set(geom.Point)) !set.Set(geom.Edge) {
    var hull_edges = set.Set(geom.Edge).init(allocator);
    errdefer hull_edges.deinit();

    // Need at least 2 points for an edge
    if (points.cardinality() < 2) return hull_edges;

    // Copy points to a slice for sorting
    var point_list: std.ArrayList(geom.Point) = .empty;
    defer point_list.deinit(allocator);

    var it = points.iterator();
    while (it.next()) |p| {
        try point_list.append(allocator, p.*);
    }

    // Find pivot: lowest y-coordinate (rightmost if tie)
    var pivot_idx: usize = 0;
    for (point_list.items, 0..) |p, i| {
        const pivot = point_list.items[pivot_idx];
        if (p.y < pivot.y or (p.y == pivot.y and p.x > pivot.x)) {
            pivot_idx = i;
        }
    }

    // Swap pivot to front
    const pivot = point_list.items[pivot_idx];
    point_list.items[pivot_idx] = point_list.items[0];
    point_list.items[0] = pivot;

    // Sort remaining points by polar angle relative to pivot
    const remaining = point_list.items[1..];
    const Context = struct {
        pivot: geom.Point,

        pub fn lessThan(ctx: @This(), a: geom.Point, b: geom.Point) bool {
            const cross = crossProduct(ctx.pivot, a, b);
            if (cross != 0) return cross > 0; // Counter-clockwise = smaller angle
            // Collinear: closer point first
            return distanceSquared(ctx.pivot, a) < distanceSquared(ctx.pivot, b);
        }
    };
    std.mem.sort(geom.Point, remaining, Context{ .pivot = pivot }, Context.lessThan);

    // Handle collinear case and small sets
    if (point_list.items.len == 2) {
        _ = try hull_edges.add(geom.Edge{ .from = point_list.items[0], .to = point_list.items[1] });
        _ = try hull_edges.add(geom.Edge{ .from = point_list.items[1], .to = point_list.items[0] });
        return hull_edges;
    }

    // Graham scan using a stack
    var stack: std.ArrayList(geom.Point) = .empty;
    defer stack.deinit(allocator);

    try stack.append(allocator, point_list.items[0]); // pivot
    try stack.append(allocator, point_list.items[1]);

    for (point_list.items[2..]) |p| {
        // Pop while we make a clockwise turn or are collinear
        while (stack.items.len >= 2) {
            const top = stack.items[stack.items.len - 1];
            const second = stack.items[stack.items.len - 2];
            const cross = crossProduct(second, top, p);
            if (cross <= 0) {
                _ = stack.pop();
            } else {
                break;
            }
        }
        try stack.append(allocator, p);
    }

    // Build edges from stack (hull vertices in counter-clockwise order)
    if (stack.items.len >= 2) {
        for (0..stack.items.len) |i| {
            const from = stack.items[i];
            const to = stack.items[(i + 1) % stack.items.len];
            _ = try hull_edges.add(geom.Edge{ .from = from, .to = to });
        }
    }

    return hull_edges;
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

// Tests for Graham Scan
test "graham scan: triangle" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });
    _ = try points.add(geom.Point{ .x = 5, .y = 10 });

    var hull = try computeGraham(allocator, points);
    defer hull.deinit();

    try std.testing.expectEqual(@as(usize, 3), hull.cardinality());
}

test "graham scan: square with interior point" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 10 });
    _ = try points.add(geom.Point{ .x = 0, .y = 10 });
    _ = try points.add(geom.Point{ .x = 5, .y = 5 }); // interior point

    var hull = try computeGraham(allocator, points);
    defer hull.deinit();

    try std.testing.expectEqual(@as(usize, 4), hull.cardinality());
}

test "graham scan: collinear points" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 5, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });

    var hull = try computeGraham(allocator, points);
    defer hull.deinit();

    // Collinear points should form a line segment (2 edges: forward and back)
    try std.testing.expectEqual(@as(usize, 2), hull.cardinality());
}

test "graham scan: two points" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 10 });

    var hull = try computeGraham(allocator, points);
    defer hull.deinit();

    try std.testing.expectEqual(@as(usize, 2), hull.cardinality());
}

test "graham scan: single point" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 5, .y = 5 });

    var hull = try computeGraham(allocator, points);
    defer hull.deinit();

    try std.testing.expectEqual(@as(usize, 0), hull.cardinality());
}
