const std = @import("std");
const set = @import("ziglangSet");
const geom = @import("geometry.zig");

/// A line segment with an ID for tracking
pub const Segment = struct {
    id: u32,
    start: geom.Point, // left endpoint (lower x)
    end: geom.Point, // right endpoint (higher x)

    pub fn init(id: u32, p1: geom.Point, p2: geom.Point) Segment {
        // Ensure start.x <= end.x
        if (p1.x < p2.x or (p1.x == p2.x and p1.y < p2.y)) {
            return Segment{ .id = id, .start = p1, .end = p2 };
        } else {
            return Segment{ .id = id, .start = p2, .end = p1 };
        }
    }

    pub fn print(self: *const Segment) void {
        std.debug.print("Segment {d}: ({d}, {d}) -> ({d}, {d})\n", .{ self.id, self.start.x, self.start.y, self.end.x, self.end.y });
    }
};

/// Types of events in the sweep line algorithm
pub const EventType = enum {
    SegmentStart,
    SegmentEnd,
    Intersection,
};

/// An event in the event queue
pub const Event = struct {
    x: i32,
    y: i32,
    event_type: EventType,
    segment1_id: u32,
    segment2_id: ?u32, // only for intersection events

    fn lessThan(context: void, a: Event, b: Event) std.math.Order {
        _ = context;
        // Sort by x first, then by y
        if (a.x != b.x) {
            return if (a.x < b.x) .lt else .gt;
        }
        if (a.y != b.y) {
            return if (a.y < b.y) .lt else .gt;
        }
        // Prioritize: Start > Intersection > End
        const type_order = struct {
            fn order(t: EventType) u8 {
                return switch (t) {
                    .SegmentStart => 0,
                    .Intersection => 1,
                    .SegmentEnd => 2,
                };
            }
        };
        const order_a = type_order.order(a.event_type);
        const order_b = type_order.order(b.event_type);
        if (order_a != order_b) {
            return if (order_a < order_b) .lt else .gt;
        }
        return .eq;
    }
};

/// An intersection point between two segments
pub const Intersection = struct {
    x: i32,
    y: i32,
    segment1_id: u32,
    segment2_id: u32,

    pub fn print(self: *const Intersection) void {
        std.debug.print("Intersection at ({d}, {d}) between segments {d} and {d}\n", .{ self.x, self.y, self.segment1_id, self.segment2_id });
    }
};

/// Compute the y-coordinate of a segment at a given x
fn yAtX(segment: Segment, x: i32) f64 {
    if (segment.start.x == segment.end.x) {
        return @floatFromInt(segment.start.y);
    }
    const dx: f64 = @floatFromInt(segment.end.x - segment.start.x);
    const dy: f64 = @floatFromInt(segment.end.y - segment.start.y);
    const t: f64 = @as(f64, @floatFromInt(x - segment.start.x)) / dx;
    return @as(f64, @floatFromInt(segment.start.y)) + t * dy;
}

/// Check if two segments intersect and return the intersection point
fn segmentIntersection(s1: Segment, s2: Segment) ?struct { x: i32, y: i32 } {
    const x1: f64 = @floatFromInt(s1.start.x);
    const y1: f64 = @floatFromInt(s1.start.y);
    const x2: f64 = @floatFromInt(s1.end.x);
    const y2: f64 = @floatFromInt(s1.end.y);
    const x3: f64 = @floatFromInt(s2.start.x);
    const y3: f64 = @floatFromInt(s2.start.y);
    const x4: f64 = @floatFromInt(s2.end.x);
    const y4: f64 = @floatFromInt(s2.end.y);

    const denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (@abs(denom) < 1e-10) return null; // parallel or coincident

    const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    const u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom;

    const epsilon = 1e-9;
    if (t >= -epsilon and t <= 1.0 + epsilon and u >= -epsilon and u <= 1.0 + epsilon) {
        const ix = x1 + t * (x2 - x1);
        const iy = y1 + t * (y2 - y1);
        return .{ .x = @intFromFloat(@round(ix)), .y = @intFromFloat(@round(iy)) };
    }

    return null;
}

/// Sweep line status - maintains active segments sorted by y at current x
const SweepLine = struct {
    segments: std.ArrayList(u32),
    segment_map: []const Segment,
    current_x: i32,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, segment_map: []const Segment) SweepLine {
        return SweepLine{
            .segments = .empty,
            .segment_map = segment_map,
            .current_x = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *SweepLine) void {
        self.segments.deinit(self.allocator);
    }

    fn setCurrentX(self: *SweepLine, x: i32) void {
        self.current_x = x;
    }

    fn getSegment(self: *const SweepLine, id: u32) Segment {
        for (self.segment_map) |seg| {
            if (seg.id == id) return seg;
        }
        unreachable;
    }

    fn insert(self: *SweepLine, segment_id: u32) !void {
        const seg = self.getSegment(segment_id);
        const y = yAtX(seg, self.current_x);

        // Find insertion position
        var pos: usize = 0;
        for (self.segments.items) |id| {
            const other_seg = self.getSegment(id);
            const other_y = yAtX(other_seg, self.current_x);
            if (y < other_y) break;
            pos += 1;
        }

        try self.segments.insert(self.allocator, pos, segment_id);
    }

    fn remove(self: *SweepLine, segment_id: u32) void {
        for (self.segments.items, 0..) |id, i| {
            if (id == segment_id) {
                _ = self.segments.orderedRemove(i);
                return;
            }
        }
    }

    fn findPosition(self: *const SweepLine, segment_id: u32) ?usize {
        for (self.segments.items, 0..) |id, i| {
            if (id == segment_id) return i;
        }
        return null;
    }

    fn getNeighbors(self: *const SweepLine, segment_id: u32) struct { above: ?u32, below: ?u32 } {
        const pos = self.findPosition(segment_id) orelse return .{ .above = null, .below = null };
        return .{
            .above = if (pos + 1 < self.segments.items.len) self.segments.items[pos + 1] else null,
            .below = if (pos > 0) self.segments.items[pos - 1] else null,
        };
    }

    fn swap(self: *SweepLine, id1: u32, id2: u32) void {
        var pos1: ?usize = null;
        var pos2: ?usize = null;
        for (self.segments.items, 0..) |id, i| {
            if (id == id1) pos1 = i;
            if (id == id2) pos2 = i;
        }
        if (pos1 != null and pos2 != null) {
            const temp = self.segments.items[pos1.?];
            self.segments.items[pos1.?] = self.segments.items[pos2.?];
            self.segments.items[pos2.?] = temp;
        }
    }
};

/// Find all intersections using Bentley-Ottmann algorithm
pub fn findIntersections(allocator: std.mem.Allocator, segments: []const Segment) !std.ArrayList(Intersection) {
    var intersections: std.ArrayList(Intersection) = .empty;
    errdefer intersections.deinit(allocator);

    if (segments.len < 2) return intersections;

    // Event queue (priority queue)
    var event_queue = std.PriorityQueue(Event, void, Event.lessThan).init(allocator, {});
    defer event_queue.deinit();

    // Initialize with segment start/end events
    for (segments) |seg| {
        try event_queue.add(Event{
            .x = seg.start.x,
            .y = seg.start.y,
            .event_type = .SegmentStart,
            .segment1_id = seg.id,
            .segment2_id = null,
        });
        try event_queue.add(Event{
            .x = seg.end.x,
            .y = seg.end.y,
            .event_type = .SegmentEnd,
            .segment1_id = seg.id,
            .segment2_id = null,
        });
    }

    // Sweep line status
    var sweep_line = SweepLine.init(allocator, segments);
    defer sweep_line.deinit();

    // Track processed intersections to avoid duplicates
    var processed = std.AutoHashMap(u64, void).init(allocator);
    defer processed.deinit();

    const makeKey = struct {
        fn f(id1: u32, id2: u32) u64 {
            const min_id = @min(id1, id2);
            const max_id = @max(id1, id2);
            return @as(u64, min_id) << 32 | @as(u64, max_id);
        }
    }.f;

    // Process events
    while (event_queue.count() > 0) {
        const event = event_queue.remove();
        sweep_line.setCurrentX(event.x);

        switch (event.event_type) {
            .SegmentStart => {
                try sweep_line.insert(event.segment1_id);
                const neighbors = sweep_line.getNeighbors(event.segment1_id);

                // Check intersection with neighbors
                const seg = sweep_line.getSegment(event.segment1_id);
                if (neighbors.above) |above_id| {
                    const above_seg = sweep_line.getSegment(above_id);
                    if (segmentIntersection(seg, above_seg)) |pt| {
                        if (pt.x >= event.x) {
                            const key = makeKey(event.segment1_id, above_id);
                            if (!processed.contains(key)) {
                                try processed.put(key, {});
                                try event_queue.add(Event{
                                    .x = pt.x,
                                    .y = pt.y,
                                    .event_type = .Intersection,
                                    .segment1_id = event.segment1_id,
                                    .segment2_id = above_id,
                                });
                            }
                        }
                    }
                }
                if (neighbors.below) |below_id| {
                    const below_seg = sweep_line.getSegment(below_id);
                    if (segmentIntersection(seg, below_seg)) |pt| {
                        if (pt.x >= event.x) {
                            const key = makeKey(event.segment1_id, below_id);
                            if (!processed.contains(key)) {
                                try processed.put(key, {});
                                try event_queue.add(Event{
                                    .x = pt.x,
                                    .y = pt.y,
                                    .event_type = .Intersection,
                                    .segment1_id = event.segment1_id,
                                    .segment2_id = below_id,
                                });
                            }
                        }
                    }
                }
            },
            .SegmentEnd => {
                const neighbors = sweep_line.getNeighbors(event.segment1_id);
                sweep_line.remove(event.segment1_id);

                // Check if former neighbors now intersect
                if (neighbors.above != null and neighbors.below != null) {
                    const above_seg = sweep_line.getSegment(neighbors.above.?);
                    const below_seg = sweep_line.getSegment(neighbors.below.?);
                    if (segmentIntersection(above_seg, below_seg)) |pt| {
                        if (pt.x >= event.x) {
                            const key = makeKey(neighbors.above.?, neighbors.below.?);
                            if (!processed.contains(key)) {
                                try processed.put(key, {});
                                try event_queue.add(Event{
                                    .x = pt.x,
                                    .y = pt.y,
                                    .event_type = .Intersection,
                                    .segment1_id = neighbors.above.?,
                                    .segment2_id = neighbors.below.?,
                                });
                            }
                        }
                    }
                }
            },
            .Intersection => {
                try intersections.append(allocator, Intersection{
                    .x = event.x,
                    .y = event.y,
                    .segment1_id = event.segment1_id,
                    .segment2_id = event.segment2_id.?,
                });

                // Swap segments in sweep line
                sweep_line.swap(event.segment1_id, event.segment2_id.?);

                // Check new neighbors for intersections
                const neighbors1 = sweep_line.getNeighbors(event.segment1_id);
                const neighbors2 = sweep_line.getNeighbors(event.segment2_id.?);

                const seg1 = sweep_line.getSegment(event.segment1_id);
                const seg2 = sweep_line.getSegment(event.segment2_id.?);

                // Check seg1's new neighbors
                if (neighbors1.above) |above_id| {
                    if (above_id != event.segment2_id.?) {
                        const above_seg = sweep_line.getSegment(above_id);
                        if (segmentIntersection(seg1, above_seg)) |pt| {
                            if (pt.x > event.x) {
                                const key = makeKey(event.segment1_id, above_id);
                                if (!processed.contains(key)) {
                                    try processed.put(key, {});
                                    try event_queue.add(Event{
                                        .x = pt.x,
                                        .y = pt.y,
                                        .event_type = .Intersection,
                                        .segment1_id = event.segment1_id,
                                        .segment2_id = above_id,
                                    });
                                }
                            }
                        }
                    }
                }
                if (neighbors1.below) |below_id| {
                    if (below_id != event.segment2_id.?) {
                        const below_seg = sweep_line.getSegment(below_id);
                        if (segmentIntersection(seg1, below_seg)) |pt| {
                            if (pt.x > event.x) {
                                const key = makeKey(event.segment1_id, below_id);
                                if (!processed.contains(key)) {
                                    try processed.put(key, {});
                                    try event_queue.add(Event{
                                        .x = pt.x,
                                        .y = pt.y,
                                        .event_type = .Intersection,
                                        .segment1_id = event.segment1_id,
                                        .segment2_id = below_id,
                                    });
                                }
                            }
                        }
                    }
                }

                // Check seg2's new neighbors
                if (neighbors2.above) |above_id| {
                    if (above_id != event.segment1_id) {
                        const above_seg = sweep_line.getSegment(above_id);
                        if (segmentIntersection(seg2, above_seg)) |pt| {
                            if (pt.x > event.x) {
                                const key = makeKey(event.segment2_id.?, above_id);
                                if (!processed.contains(key)) {
                                    try processed.put(key, {});
                                    try event_queue.add(Event{
                                        .x = pt.x,
                                        .y = pt.y,
                                        .event_type = .Intersection,
                                        .segment1_id = event.segment2_id.?,
                                        .segment2_id = above_id,
                                    });
                                }
                            }
                        }
                    }
                }
                if (neighbors2.below) |below_id| {
                    if (below_id != event.segment1_id) {
                        const below_seg = sweep_line.getSegment(below_id);
                        if (segmentIntersection(seg2, below_seg)) |pt| {
                            if (pt.x > event.x) {
                                const key = makeKey(event.segment2_id.?, below_id);
                                if (!processed.contains(key)) {
                                    try processed.put(key, {});
                                    try event_queue.add(Event{
                                        .x = pt.x,
                                        .y = pt.y,
                                        .event_type = .Intersection,
                                        .segment1_id = event.segment2_id.?,
                                        .segment2_id = below_id,
                                    });
                                }
                            }
                        }
                    }
                }
            },
        }
    }

    return intersections;
}

/// Generate random segments for testing
pub fn generateRandomSegments(n: usize, allocator: std.mem.Allocator, io: std.Io) !std.ArrayList(Segment) {
    var prng = std.Random.DefaultPrng.init(@intCast(std.Io.Clock.now(.awake, io).toMilliseconds()));
    const random = prng.random();

    var segments: std.ArrayList(Segment) = .empty;
    errdefer segments.deinit(allocator);

    var id: u32 = 0;
    while (segments.items.len < n) : (id += 1) {
        const p1 = geom.Point{
            .x = random.intRangeAtMost(i32, 5, 95),
            .y = random.intRangeAtMost(i32, 5, 95),
        };
        const p2 = geom.Point{
            .x = random.intRangeAtMost(i32, 5, 95),
            .y = random.intRangeAtMost(i32, 5, 95),
        };
        // Skip degenerate segments
        if (p1.x == p2.x and p1.y == p2.y) continue;
        try segments.append(allocator, Segment.init(id, p1, p2));
    }

    return segments;
}

// Tests
test "bentley-ottmann: no intersections" {
    const allocator = std.testing.allocator;

    var segments = [_]Segment{
        Segment.init(0, geom.Point{ .x = 0, .y = 0 }, geom.Point{ .x = 10, .y = 0 }),
        Segment.init(1, geom.Point{ .x = 0, .y = 10 }, geom.Point{ .x = 10, .y = 10 }),
    };

    var intersections = try findIntersections(allocator, &segments);
    defer intersections.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), intersections.items.len);
}

test "bentley-ottmann: single intersection (X)" {
    const allocator = std.testing.allocator;

    var segments = [_]Segment{
        Segment.init(0, geom.Point{ .x = 0, .y = 0 }, geom.Point{ .x = 10, .y = 10 }),
        Segment.init(1, geom.Point{ .x = 0, .y = 10 }, geom.Point{ .x = 10, .y = 0 }),
    };

    var intersections = try findIntersections(allocator, &segments);
    defer intersections.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), intersections.items.len);
    try std.testing.expectEqual(@as(i32, 5), intersections.items[0].x);
    try std.testing.expectEqual(@as(i32, 5), intersections.items[0].y);
}

test "bentley-ottmann: multiple intersections" {
    const allocator = std.testing.allocator;

    // Grid pattern: 2 horizontal + 2 vertical = 4 intersections
    var segments = [_]Segment{
        Segment.init(0, geom.Point{ .x = 0, .y = 3 }, geom.Point{ .x = 10, .y = 3 }),
        Segment.init(1, geom.Point{ .x = 0, .y = 7 }, geom.Point{ .x = 10, .y = 7 }),
        Segment.init(2, geom.Point{ .x = 3, .y = 0 }, geom.Point{ .x = 3, .y = 10 }),
        Segment.init(3, geom.Point{ .x = 7, .y = 0 }, geom.Point{ .x = 7, .y = 10 }),
    };

    var intersections = try findIntersections(allocator, &segments);
    defer intersections.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), intersections.items.len);
}

test "bentley-ottmann: touching at endpoint" {
    const allocator = std.testing.allocator;

    var segments = [_]Segment{
        Segment.init(0, geom.Point{ .x = 0, .y = 0 }, geom.Point{ .x = 5, .y = 5 }),
        Segment.init(1, geom.Point{ .x = 5, .y = 5 }, geom.Point{ .x = 10, .y = 0 }),
    };

    var intersections = try findIntersections(allocator, &segments);
    defer intersections.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), intersections.items.len);
}
