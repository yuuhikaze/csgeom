const std = @import("std");
const set = @import("ziglangSet");
const geom = @import("geometry.zig");

/// Floating-point 2D point for precise calculations
pub const PointF64 = struct {
    x: f64,
    y: f64,

    pub fn fromPoint(p: geom.Point) PointF64 {
        return PointF64{
            .x = @floatFromInt(p.x),
            .y = @floatFromInt(p.y),
        };
    }

    pub fn distanceTo(self: PointF64, other: PointF64) f64 {
        const dx = other.x - self.x;
        const dy = other.y - self.y;
        return @sqrt(dx * dx + dy * dy);
    }

    pub fn distanceSquaredTo(self: PointF64, other: PointF64) f64 {
        const dx = other.x - self.x;
        const dy = other.y - self.y;
        return dx * dx + dy * dy;
    }
};

/// Circle defined by center and radius
pub const Circle = struct {
    center: PointF64,
    radius: f64,

    pub fn containsPoint(self: Circle, p: PointF64) bool {
        const epsilon = 1e-9;
        return self.center.distanceSquaredTo(p) <= (self.radius + epsilon) * (self.radius + epsilon);
    }
};

/// Create a circle from 0, 1, 2, or 3 boundary points
fn trivialCircle(boundary: []const PointF64) Circle {
    return switch (boundary.len) {
        0 => Circle{ .center = PointF64{ .x = 0, .y = 0 }, .radius = 0 },
        1 => Circle{ .center = boundary[0], .radius = 0 },
        2 => circleFromTwoPoints(boundary[0], boundary[1]),
        3 => circleFromThreePoints(boundary[0], boundary[1], boundary[2]),
        else => unreachable,
    };
}

/// Circle with diameter between two points
fn circleFromTwoPoints(p1: PointF64, p2: PointF64) Circle {
    const center = PointF64{
        .x = (p1.x + p2.x) / 2.0,
        .y = (p1.y + p2.y) / 2.0,
    };
    return Circle{
        .center = center,
        .radius = center.distanceTo(p1),
    };
}

/// Check if three points are collinear
fn areCollinear(p1: PointF64, p2: PointF64, p3: PointF64) bool {
    const epsilon = 1e-9;
    const cross = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x);
    return @abs(cross) < epsilon;
}

/// Circumcircle of three points (or diameter circle if collinear)
fn circleFromThreePoints(p1: PointF64, p2: PointF64, p3: PointF64) Circle {
    // Handle collinear case: use farthest pair as diameter
    if (areCollinear(p1, p2, p3)) {
        const d12 = p1.distanceSquaredTo(p2);
        const d23 = p2.distanceSquaredTo(p3);
        const d13 = p1.distanceSquaredTo(p3);
        if (d12 >= d23 and d12 >= d13) return circleFromTwoPoints(p1, p2);
        if (d23 >= d12 and d23 >= d13) return circleFromTwoPoints(p2, p3);
        return circleFromTwoPoints(p1, p3);
    }

    // Calculate circumcenter using perpendicular bisectors
    const ax = p1.x;
    const ay = p1.y;
    const bx = p2.x;
    const by = p2.y;
    const cx = p3.x;
    const cy = p3.y;

    const d = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    const ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d;
    const uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d;

    const center = PointF64{ .x = ux, .y = uy };
    return Circle{
        .center = center,
        .radius = center.distanceTo(p1),
    };
}

/// Welzl's algorithm - recursive helper with boundary points
/// welzl_b(P, R): compute smallest circle containing P with R on boundary
fn welzlRecursive(points: []PointF64, n: usize, boundary: *[3]PointF64, b: usize) Circle {
    // Base case: no points left or 3 boundary points (circle is determined)
    if (n == 0 or b == 3) {
        return trivialCircle(boundary[0..b]);
    }

    // Pick the last point (after shuffle, this is random)
    const p = points[n - 1];

    // Recursively get circle without this point
    var circle = welzlRecursive(points, n - 1, boundary, b);

    // If p is inside the circle, we're done
    if (circle.containsPoint(p)) {
        return circle;
    }

    // Otherwise, p must be on the boundary of the minimum circle
    boundary[b] = p;
    return welzlRecursive(points, n - 1, boundary, b + 1);
}

/// Computes minimum enclosing circle using Welzl's algorithm
/// Expected O(n) time complexity
pub fn computeWelzl(allocator: std.mem.Allocator, points: set.Set(geom.Point)) !Circle {
    if (points.cardinality() == 0) {
        return Circle{ .center = PointF64{ .x = 0, .y = 0 }, .radius = 0 };
    }

    // Convert to f64 points
    var point_list: std.ArrayList(PointF64) = .empty;
    defer point_list.deinit(allocator);

    var it = points.iterator();
    while (it.next()) |p| {
        try point_list.append(allocator, PointF64.fromPoint(p.*));
    }

    // Use simple PRNG
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();

    return welzlSimple(allocator, point_list.items, rng);
}

// Add a test that checks all points are contained
test "welzl: all points contained" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    // Add various points spread across the space
    _ = try points.add(geom.Point{ .x = 0, .y = 50 });
    _ = try points.add(geom.Point{ .x = 100, .y = 50 });
    _ = try points.add(geom.Point{ .x = 50, .y = 0 });
    _ = try points.add(geom.Point{ .x = 50, .y = 100 });
    _ = try points.add(geom.Point{ .x = 25, .y = 25 });
    _ = try points.add(geom.Point{ .x = 75, .y = 75 });

    const circle = try computeWelzl(allocator, points);

    // Verify all points are contained
    var it = points.iterator();
    while (it.next()) |p| {
        const pf = PointF64.fromPoint(p.*);
        try std.testing.expect(circle.containsPoint(pf));
    }
}

/// Welzl's algorithm entry point
fn welzlSimple(allocator: std.mem.Allocator, points: []PointF64, rng: std.Random) Circle {
    _ = allocator;

    if (points.len == 0) return Circle{ .center = PointF64{ .x = 0, .y = 0 }, .radius = 0 };
    if (points.len == 1) return Circle{ .center = points[0], .radius = 0 };

    // Shuffle for randomization (expected O(n) time)
    rng.shuffle(PointF64, points);

    // Start recursive algorithm with empty boundary
    var boundary: [3]PointF64 = undefined;
    return welzlRecursive(points, points.len, &boundary, 0);
}

// Tests
test "welzl: single point" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 5, .y = 5 });

    const circle = try computeWelzl(allocator, points);

    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.center.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.center.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), circle.radius, 0.001);
}

test "welzl: two points" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });

    const circle = try computeWelzl(allocator, points);

    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.center.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), circle.center.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.radius, 0.001);
}

test "welzl: equilateral triangle" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });
    _ = try points.add(geom.Point{ .x = 5, .y = 9 }); // Approximate equilateral

    const circle = try computeWelzl(allocator, points);

    // All points should be contained
    try std.testing.expect(circle.containsPoint(PointF64{ .x = 0, .y = 0 }));
    try std.testing.expect(circle.containsPoint(PointF64{ .x = 10, .y = 0 }));
    try std.testing.expect(circle.containsPoint(PointF64{ .x = 5, .y = 9 }));
}

test "welzl: square" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 10 });
    _ = try points.add(geom.Point{ .x = 0, .y = 10 });

    const circle = try computeWelzl(allocator, points);

    // Center should be at (5, 5)
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.center.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.center.y, 0.001);
    // Radius should be half diagonal: sqrt(50) ≈ 7.07
    try std.testing.expectApproxEqAbs(@as(f64, 7.071), circle.radius, 0.01);
}

test "welzl: collinear points" {
    const allocator = std.testing.allocator;
    var points = set.Set(geom.Point).init(allocator);
    defer points.deinit();

    _ = try points.add(geom.Point{ .x = 0, .y = 0 });
    _ = try points.add(geom.Point{ .x = 5, .y = 0 });
    _ = try points.add(geom.Point{ .x = 10, .y = 0 });

    const circle = try computeWelzl(allocator, points);

    // Should be diameter from (0,0) to (10,0)
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.center.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), circle.center.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), circle.radius, 0.001);
}
