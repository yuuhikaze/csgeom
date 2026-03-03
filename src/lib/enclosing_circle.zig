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

/// Welzl's recursive algorithm (iterative version to avoid stack overflow)
fn welzlIterative(allocator: std.mem.Allocator, points: []PointF64, rng: std.Random) !Circle {
    // Shuffle points randomly
    rng.shuffle(PointF64, points);

    var boundary: std.ArrayList(PointF64) = .empty;
    defer boundary.deinit(allocator);

    var circle = trivialCircle(&[_]PointF64{});

    for (points) |p| {
        if (!circle.containsPoint(p)) {
            // Point is outside, must be on boundary
            boundary.clearRetainingCapacity();
            try boundary.append(allocator, p);
            circle = welzlWithBoundary(allocator, points[0..0], boundary.items, p, rng) catch trivialCircle(boundary.items);

            // Rebuild with all previous points
            circle = try rebuildWithPoint(allocator, points, p, rng);
        }
    }

    return circle;
}

fn rebuildWithPoint(allocator: std.mem.Allocator, points: []PointF64, new_point: PointF64, rng: std.Random) !Circle {
    var boundary: std.ArrayList(PointF64) = .empty;
    defer boundary.deinit(allocator);
    try boundary.append(allocator, new_point);

    var circle = trivialCircle(boundary.items);

    for (points) |p| {
        if (p.x == new_point.x and p.y == new_point.y) continue;
        if (!circle.containsPoint(p)) {
            try boundary.append(allocator, p);
            if (boundary.items.len <= 3) {
                circle = trivialCircle(boundary.items);
            } else {
                // Need to restart with new boundary
                circle = try rebuildWithTwoPoints(allocator, points, boundary.items[0], p, rng);
                boundary.clearRetainingCapacity();
                try boundary.append(allocator, boundary.items[0]);
                try boundary.append(allocator, p);
            }
        }
    }

    return circle;
}

fn rebuildWithTwoPoints(allocator: std.mem.Allocator, points: []PointF64, b1: PointF64, b2: PointF64, rng: std.Random) !Circle {
    _ = rng;
    var boundary = [_]PointF64{ b1, b2, undefined };
    var boundary_count: usize = 2;

    var circle = trivialCircle(boundary[0..boundary_count]);

    for (points) |p| {
        if ((p.x == b1.x and p.y == b1.y) or (p.x == b2.x and p.y == b2.y)) continue;
        if (!circle.containsPoint(p)) {
            if (boundary_count < 3) {
                boundary[boundary_count] = p;
                boundary_count += 1;
                circle = trivialCircle(boundary[0..boundary_count]);
            }
            // With 3 boundary points, circle is fully determined
        }
    }

    _ = allocator;
    return circle;
}

fn welzlWithBoundary(allocator: std.mem.Allocator, points: []PointF64, boundary: []PointF64, new_point: PointF64, rng: std.Random) !Circle {
    _ = allocator;
    _ = points;
    _ = rng;

    if (boundary.len >= 3) {
        return trivialCircle(boundary);
    }

    var new_boundary: [3]PointF64 = undefined;
    for (boundary, 0..) |b, i| {
        new_boundary[i] = b;
    }
    new_boundary[boundary.len] = new_point;

    return trivialCircle(new_boundary[0..boundary.len + 1]);
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

/// Simple iterative Welzl implementation
fn welzlSimple(allocator: std.mem.Allocator, points: []PointF64, rng: std.Random) !Circle {
    if (points.len == 0) return Circle{ .center = PointF64{ .x = 0, .y = 0 }, .radius = 0 };
    if (points.len == 1) return Circle{ .center = points[0], .radius = 0 };

    // Shuffle for randomization
    rng.shuffle(PointF64, points);

    // Start with circle through first point
    var boundary: std.ArrayList(PointF64) = .empty;
    defer boundary.deinit(allocator);

    var circle = Circle{ .center = points[0], .radius = 0 };

    var i: usize = 1;
    while (i < points.len) : (i += 1) {
        if (!circle.containsPoint(points[i])) {
            // Restart with points[i] on boundary
            boundary.clearRetainingCapacity();
            try boundary.append(allocator, points[i]);
            circle = trivialCircle(boundary.items);

            // Re-add all previous points
            var j: usize = 0;
            while (j < i) : (j += 1) {
                if (!circle.containsPoint(points[j])) {
                    try boundary.append(allocator, points[j]);
                    if (boundary.items.len <= 3) {
                        circle = trivialCircle(boundary.items);
                    }
                    if (boundary.items.len == 3) {
                        // Circle determined, check remaining previous points
                        // If any fail, we need different boundary - restart j
                        var valid = true;
                        for (0..j) |k| {
                            if (!circle.containsPoint(points[k])) {
                                valid = false;
                                break;
                            }
                        }
                        if (!valid) {
                            // Try with different third point
                            _ = boundary.pop();
                        }
                    }
                }
            }
        }
    }

    return circle;
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
