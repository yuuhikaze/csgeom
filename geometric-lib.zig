const std = @import("std");

/// Represents a point in 2D space
pub const Point = struct {
    x: i32,
    y: i32,
};

/// Generates a set of N unique random points.
/// Caller owns the returned HashMap and must deinit it.
pub fn generateRandomPoints(allocator: std.mem.Allocator, n: usize) !std.AutoHashMap(Point, void) {
    // var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var prng = std.Random.DefaultPrng.init(1234);
    const random = prng.random();

    var point_set = std.AutoHashMap(Point, void).init(allocator);
    errdefer point_set.deinit(); // Clean up if an error occurs during the loop

    while (point_set.count() < n) {
        const p = Point{
            .x = random.intRangeAtMost(i32, 0, 100),
            .y = random.intRangeAtMost(i32, 0, 100),
        };
        try point_set.put(p, {});
    }
    return point_set;
}

pub fn calculateCrossProduct(u: Point, v: Point) bool {
    return u.x * v.y - u.y * v.x < 0;
}
