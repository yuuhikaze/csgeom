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
/// Caller owns the returned Set and must deinit it.
pub fn generateRandomPoints(n: usize, allocator: std.mem.Allocator, io: std.Io) !set.Set(Point) {
    var prng = std.Random.DefaultPrng.init(@intCast(std.Io.Clock.now(.awake, io).toMilliseconds()));
    const random = prng.random();

    var point_set = set.Set(Point).init(allocator);
    errdefer point_set.deinit();

    while (point_set.cardinality() < n) {
        const p = Point{
            .x = random.intRangeAtMost(i32, 0, 100),
            .y = random.intRangeAtMost(i32, 0, 100),
        };
        _ = try point_set.add(p);
    }
    return point_set;
}

/// Generates a set of N unique edges.
/// Caller owns the returned Set and must deinit it.
pub fn generateRandomEdges(n: usize, allocator: std.mem.Allocator, io: std.Io) !set.Set(Edge) {
    var prng = std.Random.DefaultPrng.init(@intCast(std.Io.Clock.now(.awake, io).toMilliseconds()));
    const random = prng.random();

    var edge_set = set.Set(Edge).init(allocator);
    errdefer edge_set.deinit();

    while (edge_set.cardinality() < n) {
        const from = Point{
            .x = random.intRangeAtMost(i32, 20, 80),
            .y = random.intRangeAtMost(i32, 20, 80),
        };
        const to = Point{
            .x = from.x + random.intRangeAtMost(i32, -20, 20),
            .y = from.y + random.intRangeAtMost(i32, -20, 20),
        };
        _ = try edge_set.add(Edge{
            .from = from,
            .to = to,
        });
    }
    return edge_set;
}

/// Calculates the 2D cross product of two vectors
pub fn calculateCrossProduct(u: Point, v: Point) i32 {
    return u.x * v.y - u.y * v.x;
}

/// Creates a vector from point a to point b
pub fn createVector(a: *Point, b: *Point) Point {
    return Point{ .x = b.x - a.x, .y = b.y - a.y };
}
