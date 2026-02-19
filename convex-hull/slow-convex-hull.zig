const std = @import("std");
const geo = @import("lib.zig");

/// Represents a point in 2D space
const Point = struct {
    x: i32,
    y: i32,
};

pub fn main() !void {
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
}
