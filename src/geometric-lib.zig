const std = @import("std");
const set = @import("ziglangSet");

/// Represents an edge in 2D space
pub const Edge = struct {
    from: Point,
    to: Point,

    pub fn print(self: *Edge) void {
        std.debug.print("({}, {}) -> ({}, {})\n", .{ self.from.x, self.from.y, self.to.x, self.to.y });
    }
};

/// Represents a point in 2D space
pub const Point = struct {
    x: i32,
    y: i32,

    pub fn print(self: *Point) void {
        std.debug.print("({}, {})\n", .{ self.x, self.y });
    }
};

/// Generates a set of N unique random points.
/// Caller owns the returned HashMap and must deinit it.
pub fn generateRandomPoints(allocator: std.mem.Allocator, n: usize) !set.Set(Point) {
    // var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var prng = std.Random.DefaultPrng.init(1234);
    const random = prng.random();

    var point_set = set.Set(Point).init(allocator);
    errdefer point_set.deinit(); // Clean up if an error occurs during the loop

    // note: this could be made shorter
    while (point_set.cardinality() < n) {
        const p = Point{
            .x = random.intRangeAtMost(i32, 0, 100),
            .y = random.intRangeAtMost(i32, 0, 100),
        };
        _ = try point_set.add(p);
    }
    return point_set;
}

pub fn calculateCrossProduct(u: Point, v: Point) i32 {
    return u.x * v.y - u.y * v.x;
}

pub fn create_vector(a: *Point, b: *Point) Point {
    return Point{ .x = b.x - a.x, .y = b.y - a.y };
}
