const std = @import("std");
const set = @import("ziglangSet");
const geom = @import("geometry.zig");
const rbt = @import("red_black_tree.zig");

const Point = geom.Point;
const Edge = geom.Edge;
const RBTree = rbt.RBTree;
const Order = rbt.Order;

// ============================================================================
// Event Types and Structures
// ============================================================================

/// Type of event in the sweep line algorithm
const EventType = enum {
    START, // Segment starts (upper endpoint)
    END, // Segment ends (lower endpoint)
    INTERSECTION, // Segments intersect at a point
};

/// Event in the sweep line algorithm (de Berg's top-to-bottom approach)
/// Events are processed in order by y-coordinate (top to bottom), then x
/// Multiple segments can be associated with a single event point
const Event = struct {
    point: Point, // Location of event
    event_type: EventType, // Type of event
    segments: std.ArrayList(Edge), // All segments involved in this event
    allocator: std.mem.Allocator, // Allocator for segments list

    /// Create a START event for a segment
    pub fn start(seg: Edge, upper: Point, allocator: std.mem.Allocator) !Event {
        var segs = std.ArrayList(Edge).init(allocator);
        try segs.append(seg);
        return Event{
            .point = upper,
            .event_type = .START,
            .segments = segs,
            .allocator = allocator,
        };
    }

    /// Create an END event for a segment
    pub fn end(seg: Edge, lower: Point, allocator: std.mem.Allocator) !Event {
        var segs = std.ArrayList(Edge).init(allocator);
        try segs.append(seg);
        return Event{
            .point = lower,
            .event_type = .END,
            .segments = segs,
            .allocator = allocator,
        };
    }

    /// Create an INTERSECTION event for multiple segments
    pub fn intersection(pt: Point, segments_list: []const Edge, allocator: std.mem.Allocator) !Event {
        var segs = std.ArrayList(Edge).init(allocator);
        for (segments_list) |seg| {
            try segs.append(seg);
        }
        return Event{
            .point = pt,
            .event_type = .INTERSECTION,
            .segments = segs,
            .allocator = allocator,
        };
    }

    /// Free memory used by event
    pub fn deinit(self: *Event) void {
        self.segments.deinit();
    }
};

// ============================================================================
// Segment with Cached Value for Status Structure
// ============================================================================

/// Wrapper for segment with cached x-coordinate at current sweep line
/// This avoids repeated interpolation calculations (similar to Java implementation)
const SegmentWithCache = struct {
    segment: Edge, // The actual segment
    cached_x: f64, // x-coordinate at current sweep line y

    /// Create from segment and sweep line position
    pub fn init(seg: Edge, sweep_y: i32) SegmentWithCache {
        return SegmentWithCache{
            .segment = seg,
            .cached_x = interpolateX(seg, sweep_y),
        };
    }

    /// Update cached value for new sweep line position
    pub fn recalculate(self: *SegmentWithCache, sweep_y: i32) void {
        self.cached_x = interpolateX(self.segment, sweep_y);
    }
};

// ============================================================================
// Comparator Functions
// ============================================================================

/// Compare events for event queue ordering (de Berg's algorithm)
/// Events are ordered by:
/// 1. y-coordinate (descending - higher y values first for top-to-bottom sweep)
/// 2. x-coordinate (ascending - left to right)
/// 3. Event type priority: START < INTERSECTION < END
fn compareEvents(a: Event, b: Event) Order {
    // Compare y-coordinates (descending for top-to-bottom sweep)
    if (a.point.y > b.point.y) return .Less;
    if (a.point.y < b.point.y) return .Greater;

    // Same y: compare x-coordinates (ascending)
    if (a.point.x < b.point.x) return .Less;
    if (a.point.x > b.point.x) return .Greater;

    // Same point: prioritize event types
    // START events before INTERSECTION before END events
    const a_priority: i32 = switch (a.event_type) {
        .START => 0,
        .INTERSECTION => 1,
        .END => 2,
    };
    const b_priority: i32 = switch (b.event_type) {
        .START => 0,
        .INTERSECTION => 1,
        .END => 2,
    };

    if (a_priority < b_priority) return .Less;
    if (a_priority > b_priority) return .Greater;

    return .Equal;
}

/// Compare segments in status structure (de Berg's top-to-bottom sweep)
/// Segments are ordered by their x-coordinate at the current sweep line
/// Uses cached values for efficiency (no repeated interpolation)
fn compareSegmentsInStatus(a: SegmentWithCache, b: SegmentWithCache) Order {
    if (a.cached_x < b.cached_x) return .Less;
    if (a.cached_x > b.cached_x) return .Greater;

    // Tie-break by slope (segments with smaller slope come first)
    const slope_a = calculateSlope(a.segment);
    const slope_b = calculateSlope(b.segment);

    if (slope_a < slope_b) return .Less;
    if (slope_a > slope_b) return .Greater;

    return .Equal;
}

// ============================================================================
// Geometric Helper Functions
// ============================================================================

/// Calculate x-coordinate of segment at given y-coordinate
/// Uses linear interpolation: x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
fn interpolateX(seg: Edge, y: i32) f64 {
    const p1 = seg.from;
    const p2 = seg.to;

    // Handle horizontal segments
    if (p1.y == p2.y) {
        return @floatFromInt(@min(p1.x, p2.x));
    }

    // Linear interpolation
    const dy: f64 = @floatFromInt(p2.y - p1.y);
    const dx: f64 = @floatFromInt(p2.x - p1.x);
    const y_offset: f64 = @floatFromInt(y - p1.y);
    const x1: f64 = @floatFromInt(p1.x);

    return x1 + (y_offset * dx / dy);
}

/// Calculate slope of segment
fn calculateSlope(seg: Edge) f64 {
    const dy: f64 = @floatFromInt(seg.to.y - seg.from.y);
    const dx: f64 = @floatFromInt(seg.to.x - seg.from.x);

    if (@abs(dx) < 0.0001) {
        return if (dy > 0) 1e9 else -1e9;
    }

    return dy / dx;
}

/// Get upper endpoint of segment (higher y-coordinate)
fn getUpperEndpoint(seg: Edge) Point {
    if (seg.from.y > seg.to.y) {
        return seg.from;
    } else if (seg.to.y > seg.from.y) {
        return seg.to;
    } else {
        // Horizontal segment - return leftmost point
        return if (seg.from.x < seg.to.x) seg.from else seg.to;
    }
}

/// Get lower endpoint of segment (lower y-coordinate)
fn getLowerEndpoint(seg: Edge) Point {
    if (seg.from.y < seg.to.y) {
        return seg.from;
    } else if (seg.to.y < seg.from.y) {
        return seg.to;
    } else {
        // Horizontal segment - return rightmost point
        return if (seg.from.x > seg.to.x) seg.from else seg.to;
    }
}

/// Check if two segments intersect and return intersection point
/// Returns null if segments do not intersect
/// Uses parametric line segment intersection algorithm
fn segmentsIntersect(s1: Edge, s2: Edge) ?Point {
    const p1 = s1.from;
    const p2 = s1.to;
    const p3 = s2.from;
    const p4 = s2.to;

    // Calculate direction vectors
    const d1_x: i64 = @as(i64, p2.x) - @as(i64, p1.x);
    const d1_y: i64 = @as(i64, p2.y) - @as(i64, p1.y);
    const d2_x: i64 = @as(i64, p4.x) - @as(i64, p3.x);
    const d2_y: i64 = @as(i64, p4.y) - @as(i64, p3.y);

    // Calculate cross product (if 0, segments are parallel)
    const cross: i64 = d1_x * d2_y - d1_y * d2_x;
    if (cross == 0) return null; // Parallel segments

    // Calculate parametric intersection parameters
    const dx: i64 = @as(i64, p3.x) - @as(i64, p1.x);
    const dy: i64 = @as(i64, p3.y) - @as(i64, p1.y);

    const t_num: i64 = dx * d2_y - dy * d2_x;
    const u_num: i64 = dx * d1_y - dy * d1_x;

    // Check if intersection is within both segments
    const t_valid = if (cross > 0)
        (t_num >= 0 and t_num <= cross)
    else
        (t_num <= 0 and t_num >= cross);

    const u_valid = if (cross > 0)
        (u_num >= 0 and u_num <= cross)
    else
        (u_num <= 0 and u_num >= cross);

    if (!t_valid or !u_valid) return null;

    // Calculate intersection point
    const ix: i32 = @intCast(p1.x + @divTrunc(t_num * d1_x, cross));
    const iy: i32 = @intCast(p1.y + @divTrunc(t_num * d1_y, cross));

    return Point{ .x = ix, .y = iy };
}

/// Check if two points are equal
fn pointsEqual(p1: Point, p2: Point) bool {
    return p1.x == p2.x and p1.y == p2.y;
}

/// Check if two segments are equal (same endpoints)
fn segmentsEqual(s1: Edge, s2: Edge) bool {
    return (pointsEqual(s1.from, s2.from) and pointsEqual(s1.to, s2.to)) or
        (pointsEqual(s1.from, s2.to) and pointsEqual(s1.to, s2.from));
}

// ============================================================================
// Main Algorithm (de Berg's approach)
// ============================================================================

/// Compute all intersection points of line segments using sweep line algorithm
/// Time complexity: O((n + k) log n) where n = segments, k = intersections
/// Space complexity: O(n)
///
/// Algorithm (de Berg, Chapter 2):
/// - Horizontal sweep line moves top to bottom (decreasing y)
/// - Event queue Q: events ordered by y-coordinate (descending)
/// - Status structure T: active segments ordered by x-coordinate at sweep line
///
/// For each event:
/// - START: insert segment, check neighbors for intersections
/// - END: remove segment, check if neighbors now intersect
/// - INTERSECTION: add to results, swap segments, check new neighbors
pub fn computeTopToBottom(segments: set.Set(Edge), allocator: std.mem.Allocator) !set.Set(Point) {
    // Result set for intersection points
    var intersections = set.Set(Point).init(allocator);
    errdefer intersections.deinit();

    // Event queue (RBTree ordered by y-coordinate, top to bottom)
    var event_queue = try RBTree(Event).init(allocator, compareEvents);
    defer event_queue.deinit();

    // Populate event queue with segment endpoints
    var seg_iter = segments.iterator();
    while (seg_iter.next()) |seg| {
        const upper = getUpperEndpoint(seg);
        const lower = getLowerEndpoint(seg);

        // Add START event at upper endpoint
        const start_event = try Event.start(seg, upper, allocator);
        try event_queue.insert(start_event);

        // Add END event at lower endpoint
        const end_event = try Event.end(seg, lower, allocator);
        try event_queue.insert(end_event);
    }

    // Status structure (RBTree of segments ordered by x at sweep line)
    var status = try RBTree(SegmentWithCache).init(allocator, compareSegmentsInStatus);
    defer status.deinit();

    var current_sweep_y: i32 = std.math.maxInt(i32);

    // Process events in order
    while (!event_queue.isEmpty()) {
        // Get and remove next event
        const event_opt = event_queue.minimum();
        if (event_opt == null) break;

        var event = event_opt.?;
        _ = event_queue.delete(event);
        defer event.deinit();

        // Update sweep line position
        current_sweep_y = event.point.y;

        // Recalculate all cached x-values in status for new sweep line position
        // (Similar to Java's recalculate() method)
        try recalculateStatus(&status, current_sweep_y, allocator);

        switch (event.event_type) {
            .START => {
                // Process each segment starting at this event
                for (event.segments.items) |seg| {
                    // Insert segment into status
                    const seg_cached = SegmentWithCache.init(seg, current_sweep_y);
                    try status.insert(seg_cached);

                    // Check intersection with left neighbor
                    const left_opt = status.predecessor(seg_cached);
                    if (left_opt) |left| {
                        try reportIntersection(
                            left.segment,
                            seg,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                            allocator,
                        );
                    }

                    // Check intersection with right neighbor
                    const right_opt = status.successor(seg_cached);
                    if (right_opt) |right| {
                        try reportIntersection(
                            seg,
                            right.segment,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                            allocator,
                        );
                    }

                    // Remove future intersection between neighbors (they're no longer adjacent)
                    if (left_opt != null and right_opt != null) {
                        removeFutureIntersection(&event_queue, left_opt.?.segment, right_opt.?.segment);
                    }
                }
            },

            .END => {
                // Process each segment ending at this event
                for (event.segments.items) |seg| {
                    const seg_cached = SegmentWithCache.init(seg, current_sweep_y);

                    // Get neighbors before removal
                    const left_opt = status.predecessor(seg_cached);
                    const right_opt = status.successor(seg_cached);

                    // Remove segment from status
                    _ = status.delete(seg_cached);

                    // Check if left and right neighbors now intersect
                    if (left_opt != null and right_opt != null) {
                        try reportIntersection(
                            left_opt.?.segment,
                            right_opt.?.segment,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                            allocator,
                        );
                    }
                }
            },

            .INTERSECTION => {
                // Add intersection point to results
                _ = try intersections.add(event.point);

                // Swap all intersecting segments in status
                // (Remove, re-insert to get new ordering after intersection)
                if (event.segments.items.len >= 2) {
                    const seg1 = event.segments.items[0];
                    const seg2 = event.segments.items[1];

                    const cached1 = SegmentWithCache.init(seg1, current_sweep_y);
                    const cached2 = SegmentWithCache.init(seg2, current_sweep_y);

                    // Get neighbors before swap
                    const left_of_leftmost = status.predecessor(cached1);
                    const right_of_rightmost = status.successor(cached2);

                    // Remove both segments
                    _ = status.delete(cached1);
                    _ = status.delete(cached2);

                    // Re-insert (they'll be in swapped order now)
                    try status.insert(cached1);
                    try status.insert(cached2);

                    // Check new neighbors
                    if (left_of_leftmost != null) {
                        const leftmost = if (cached1.cached_x < cached2.cached_x) seg1 else seg2;
                        try reportIntersection(
                            left_of_leftmost.?.segment,
                            leftmost,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                            allocator,
                        );
                        const rightmost = if (cached1.cached_x < cached2.cached_x) seg2 else seg1;
                        removeFutureIntersection(&event_queue, left_of_leftmost.?.segment, rightmost);
                    }

                    if (right_of_rightmost != null) {
                        const rightmost = if (cached1.cached_x > cached2.cached_x) seg1 else seg2;
                        try reportIntersection(
                            rightmost,
                            right_of_rightmost.?.segment,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                            allocator,
                        );
                        const leftmost = if (cached1.cached_x > cached2.cached_x) seg2 else seg1;
                        removeFutureIntersection(&event_queue, leftmost, right_of_rightmost.?.segment);
                    }
                }
            },
        }
    }

    return intersections;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Recalculate cached x-values for all segments in status structure
/// Called when sweep line moves to new y-coordinate
fn recalculateStatus(status: *RBTree(SegmentWithCache), sweep_y: i32, allocator: std.mem.Allocator) !void {
    // Get all segments, recalculate, rebuild tree
    const nodes = try status.inorder();
    defer allocator.free(nodes);

    // Clear status tree
    var temp_list = std.ArrayList(Edge).init(allocator);
    defer temp_list.deinit();

    for (nodes) |node| {
        try temp_list.append(node.key.segment);
        _ = status.delete(node.key);
    }

    // Re-insert with updated cached values
    for (temp_list.items) |seg| {
        const updated = SegmentWithCache.init(seg, sweep_y);
        try status.insert(updated);
    }
}

/// Check if two segments intersect and add intersection event if found
/// Only adds intersection if it's below current sweep line (not yet processed)
fn reportIntersection(
    s1: Edge,
    s2: Edge,
    sweep_y: i32,
    event_queue: *RBTree(Event),
    intersections: *set.Set(Point),
    allocator: std.mem.Allocator,
) !void {
    const intersection_point = segmentsIntersect(s1, s2) orelse return;

    // Only add if below current sweep line
    if (intersection_point.y > sweep_y) return;

    // Don't add if already found
    if (intersections.contains(intersection_point)) return;

    // Create intersection event
    const segs = [_]Edge{ s1, s2 };
    const int_event = try Event.intersection(intersection_point, &segs, allocator);
    try event_queue.insert(int_event);
}

/// Remove future intersection event between two segments
/// Used when segments are no longer adjacent in status structure
fn removeFutureIntersection(event_queue: *RBTree(Event), s1: Edge, s2: Edge) void {
    // Get all events (inefficient but simple for now)
    const nodes = event_queue.inorder() catch return;
    defer event_queue.allocator.free(nodes);

    for (nodes) |node| {
        const event = node.key;
        if (event.event_type == .INTERSECTION and event.segments.items.len >= 2) {
            const es1 = event.segments.items[0];
            const es2 = event.segments.items[1];
            if ((segmentsEqual(es1, s1) and segmentsEqual(es2, s2)) or
                (segmentsEqual(es1, s2) and segmentsEqual(es2, s1)))
            {
                _ = event_queue.delete(event);
                return;
            }
        }
    }
}
