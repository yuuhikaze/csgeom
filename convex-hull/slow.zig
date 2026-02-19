const std = @import("std");

/// Represents a point in 2D space
const Point = struct {
    x: i32,
    y: i32,
};

/// Generates a set of N unique random points
fn generateRandomPoints(allocator: std.mem.Allocator, n: usize) !std.AutoHashMap(Point, void) {
    // Initialize Random Number Generator
    // var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    var prng = std.Random.DefaultPrng.init(@intCast(1234));
    const random = prng.random();
    // Instantiate the point "set"
    var point_set = std.AutoHashMap(Point, void).init(allocator);
    // Generate points until done
    while (point_set.count() < n) {
        // Generate random point in a 100x100 grid
        const p = Point{
            .x = random.intRangeAtMost(i32, 0, 100),
            .y = random.intRangeAtMost(i32, 0, 100),
        };
        try point_set.put(p, {});
    }

    return point_set;
}

pub fn main() !void {
    // Create GPA allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    // Generate 100 random points
    var random_points = try generateRandomPoints(allocator, 100);
    defer random_points.deinit();
    // Show results
    var it = random_points.keyIterator();
    std.debug.print("Generated {d} unique points:\n", .{random_points.count()});
    while (it.next()) |p| {
        std.debug.print("({d}, {d})\n", .{ p.x, p.y });
    }
}
