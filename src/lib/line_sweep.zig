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
    INTERSECTION, // Two segments intersect
};

/// Event in the sweep line algorithm
/// Events are processed in order by y-coordinate (top to bottom), then x
const Event = struct {
    point: Point, // Location of event
    event_type: EventType, // Type of event
    segment: ?Edge, // Associated segment (for START/END events)
    segments: ?[2]Edge, // Intersecting segments (for INTERSECTION events)

    /// Create a START event for a segment
    pub fn start(seg: Edge, upper: Point) Event {
        return Event{
            .point = upper,
            .event_type = .START,
            .segment = seg,
            .segments = null,
        };
    }

    /// Create an END event for a segment
    pub fn end(seg: Edge, lower: Point) Event {
        return Event{
            .point = lower,
            .event_type = .END,
            .segment = seg,
            .segments = null,
        };
    }

    /// Create an INTERSECTION event for two segments
    pub fn intersection(pt: Point, s1: Edge, s2: Edge) Event {
        return Event{
            .point = pt,
            .event_type = .INTERSECTION,
            .segment = null,
            .segments = [2]Edge{ s1, s2 },
        };
    }
};

// ============================================================================
// Comparator Functions
// ============================================================================

/// Compare events for event queue ordering
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

/// Context for segment comparison in status structure
/// Segments are ordered by their x-coordinate at the current sweep line
const StatusContext = struct {
    sweep_y: i32, // Current y-coordinate of sweep line
};

/// Compare segments for status structure ordering
/// Segments are ordered by their x-coordinate at the current sweep line position
/// This function needs the sweep line y-coordinate to determine ordering
fn compareSegmentsAtSweepLine(ctx: StatusContext, a: Edge, b: Edge) Order {
    // Calculate x-coordinate where each segment intersects the sweep line
    const x_a = interpolateX(a, ctx.sweep_y);
    const x_b = interpolateX(b, ctx.sweep_y);

    if (x_a < x_b) return .Less;
    if (x_a > x_b) return .Greater;

    // If x-coordinates are equal, use slope as tie-breaker
    // Segments with smaller slope (more horizontal) come first
    const slope_a = calculateSlope(a);
    const slope_b = calculateSlope(b);

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

    // Handle vertical segments (undefined slope)
    if (p1.y == p2.y) {
        // Horizontal segment - return leftmost x
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
/// Returns a large value for nearly vertical segments
fn calculateSlope(seg: Edge) f64 {
    const dy: f64 = @floatFromInt(seg.to.y - seg.from.y);
    const dx: f64 = @floatFromInt(seg.to.x - seg.from.x);

    // Avoid division by zero for vertical segments
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

    // Calculate cross product of direction vectors
    // If cross product is 0, segments are parallel
    const cross: i64 = d1_x * d2_y - d1_y * d2_x;
    if (cross == 0) {
        // Segments are parallel - check if collinear and overlapping
        // For simplicity, we'll skip collinear overlaps in this implementation
        return null;
    }

    // Calculate parametric intersection parameters t and u
    // Intersection point: p1 + t * d1 = p3 + u * d2
    const dx: i64 = @as(i64, p3.x) - @as(i64, p1.x);
    const dy: i64 = @as(i64, p3.y) - @as(i64, p1.y);

    const t_num: i64 = dx * d2_y - dy * d2_x;
    const u_num: i64 = dx * d1_y - dy * d1_x;

    // Check if intersection is within both segments (0 <= t <= 1 and 0 <= u <= 1)
    // We need: 0 <= t_num/cross <= 1 and 0 <= u_num/cross <= 1
    const t_valid = if (cross > 0)
        (t_num >= 0 and t_num <= cross)
    else
        (t_num <= 0 and t_num >= cross);

    const u_valid = if (cross > 0)
        (u_num >= 0 and u_num <= cross)
    else
        (u_num <= 0 and u_num >= cross);

    if (!t_valid or !u_valid) {
        return null; // Intersection outside segment bounds
    }

    // Calculate actual intersection point
    // Use integer arithmetic to maintain precision
    const ix: i32 = @intCast(p1.x + @divTrunc(t_num * d1_x, cross));
    const iy: i32 = @intCast(p1.y + @divTrunc(t_num * d1_y, cross));

    return Point{ .x = ix, .y = iy };
}

// ============================================================================
// Main Algorithm
// ============================================================================

/// Compute all intersection points of line segments using sweep line algorithm
/// Time complexity: O((n + k) log n) where n = number of segments, k = number of intersections
/// Space complexity: O(n)
///
/// Algorithm (Bentley-Ottmann):
/// 1. Initialize event queue with all segment endpoints
/// 2. Process events from top to bottom:
///    - START: Insert segment into status, check neighbors for intersections
///    - END: Remove segment from status, check if neighbors now intersect
///    - INTERSECTION: Add to results, swap segments in status, check new neighbors
/// 3. Return all intersection points found
///
/// Note: This implementation handles general line segments but may not detect
/// all cases of overlapping collinear segments
pub fn computeTopToBottom(segments: set.Set(Edge), allocator: std.mem.Allocator) !set.Set(Point) {
    // Initialize result set for intersection points
    var intersections = set.Set(Point).init(allocator);
    errdefer intersections.deinit();

    // Initialize event queue (ordered by y-coordinate, top to bottom)
    var event_queue = try RBTree(Event).init(allocator, compareEvents);
    defer event_queue.deinit();

    // Step 1: Populate event queue with segment endpoints
    var seg_iter = segments.iterator();
    while (seg_iter.next()) |seg| {
        const upper = getUpperEndpoint(seg);
        const lower = getLowerEndpoint(seg);

        // Add START event at upper endpoint
        try event_queue.insert(Event.start(seg, upper));

        // Add END event at lower endpoint
        try event_queue.insert(Event.end(seg, lower));
    }

    // Note: Status structure requires sweep_y, which changes during processing
    // For this implementation, we'll use a simpler approach without RBTree for status
    // and instead use an ArrayList that we keep sorted
    var status = std.ArrayList(Edge).init(allocator);
    defer status.deinit();

    var current_sweep_y: i32 = std.math.maxInt(i32); // Start from top

    // Step 2: Process events in order
    while (!event_queue.isEmpty()) {
        // Get next event (minimum in event queue)
        const event_opt = event_queue.minimum();
        if (event_opt == null) break;

        const event = event_opt.?;
        _ = event_queue.delete(event); // Remove from queue

        // Update sweep line position
        current_sweep_y = event.point.y;

        switch (event.event_type) {
            .START => {
                // Segment starts - add to status structure
                const seg = event.segment.?;

                // Insert segment into status (maintaining sorted order by x at sweep line)
                try insertSegmentIntoStatus(&status, seg, current_sweep_y);

                // Find position of newly inserted segment
                const idx = findSegmentInStatus(status.items, seg, current_sweep_y) orelse continue;

                // Check intersection with left neighbor
                if (idx > 0) {
                    const left_neighbor = status.items[idx - 1];
                    try checkAndAddIntersection(
                        left_neighbor,
                        seg,
                        current_sweep_y,
                        &event_queue,
                        &intersections,
                    );
                }

                // Check intersection with right neighbor
                if (idx + 1 < status.items.len) {
                    const right_neighbor = status.items[idx + 1];
                    try checkAndAddIntersection(
                        seg,
                        right_neighbor,
                        current_sweep_y,
                        &event_queue,
                        &intersections,
                    );
                }
            },

            .END => {
                // Segment ends - remove from status structure
                const seg = event.segment.?;

                // Find segment position before removal
                const idx = findSegmentInStatus(status.items, seg, current_sweep_y) orelse continue;

                // Get neighbors before removal
                const has_left = idx > 0;
                const has_right = idx + 1 < status.items.len;

                const left_neighbor = if (has_left) status.items[idx - 1] else null;
                const right_neighbor = if (has_right) status.items[idx + 1] else null;

                // Remove segment from status
                _ = status.orderedRemove(idx);

                // Check if left and right neighbors now intersect
                if (left_neighbor != null and right_neighbor != null) {
                    try checkAndAddIntersection(
                        left_neighbor.?,
                        right_neighbor.?,
                        current_sweep_y,
                        &event_queue,
                        &intersections,
                    );
                }
            },

            .INTERSECTION => {
                // Intersection found - add to results
                _ = try intersections.add(event.point);

                // Get intersecting segments
                const seg1 = event.segments.?[0];
                const seg2 = event.segments.?[1];

                // Find positions in status
                const idx1 = findSegmentInStatus(status.items, seg1, current_sweep_y);
                const idx2 = findSegmentInStatus(status.items, seg2, current_sweep_y);

                if (idx1 == null or idx2 == null) continue;

                // Swap segments in status (they change order after intersection)
                const min_idx = @min(idx1.?, idx2.?);
                const max_idx = @max(idx1.?, idx2.?);

                // Only swap if adjacent
                if (max_idx - min_idx == 1) {
                    const temp = status.items[min_idx];
                    status.items[min_idx] = status.items[max_idx];
                    status.items[max_idx] = temp;

                    // Check new neighbors after swap
                    // Left segment (now at max_idx) with its new left neighbor
                    if (max_idx > 0 and max_idx < status.items.len) {
                        const left_of_swapped = status.items[max_idx - 1];
                        const swapped_seg = status.items[max_idx];
                        try checkAndAddIntersection(
                            left_of_swapped,
                            swapped_seg,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                        );
                    }

                    // Right segment (now at min_idx) with its new right neighbor
                    if (min_idx + 1 < status.items.len) {
                        const swapped_seg = status.items[min_idx];
                        const right_of_swapped = status.items[min_idx + 1];
                        try checkAndAddIntersection(
                            swapped_seg,
                            right_of_swapped,
                            current_sweep_y,
                            &event_queue,
                            &intersections,
                        );
                    }
                }
            },
        }
    }

    return intersections;
}

// ============================================================================
// Status Structure Helper Functions
// ============================================================================

/// Insert segment into status structure maintaining sorted order by x at sweep line
fn insertSegmentIntoStatus(status: *std.ArrayList(Edge), seg: Edge, sweep_y: i32) !void {
    const x_seg = interpolateX(seg, sweep_y);

    // Find insertion position using binary search
    var insert_pos: usize = 0;
    for (status.items, 0..) |existing_seg, i| {
        const x_existing = interpolateX(existing_seg, sweep_y);
        if (x_seg < x_existing) {
            insert_pos = i;
            break;
        }
        insert_pos = i + 1;
    }

    // Insert at position
    try status.insert(insert_pos, seg);
}

/// Find segment in status structure
/// Returns index if found, null otherwise
fn findSegmentInStatus(status_items: []Edge, seg: Edge, sweep_y: i32) ?usize {
    const x_seg = interpolateX(seg, sweep_y);

    for (status_items, 0..) |existing_seg, i| {
        const x_existing = interpolateX(existing_seg, sweep_y);

        // Check if segments match (within small tolerance for floating point)
        if (@abs(x_seg - x_existing) < 0.001) {
            // Additional check: compare actual segments
            if (pointsEqual(existing_seg.from, seg.from) and pointsEqual(existing_seg.to, seg.to)) {
                return i;
            }
            if (pointsEqual(existing_seg.from, seg.to) and pointsEqual(existing_seg.to, seg.from)) {
                return i;
            }
        }
    }

    return null;
}

/// Check if two points are equal
fn pointsEqual(p1: Point, p2: Point) bool {
    return p1.x == p2.x and p1.y == p2.y;
}

// ============================================================================
// Intersection Detection Helper
// ============================================================================

/// Check if two segments intersect and add intersection event if found
/// Only adds intersection if it's below the current sweep line (not yet processed)
fn checkAndAddIntersection(
    s1: Edge,
    s2: Edge,
    sweep_y: i32,
    event_queue: *RBTree(Event),
    intersections: *set.Set(Point),
) !void {
    // Check if segments intersect
    const intersection_point = segmentsIntersect(s1, s2) orelse return;

    // Only add intersection if it's below or at current sweep line
    if (intersection_point.y > sweep_y) {
        return; // Intersection above sweep line - already processed
    }

    // Check if intersection already found
    if (intersections.contains(intersection_point)) {
        return; // Already processed
    }

    // Add intersection event to queue
    try event_queue.insert(Event.intersection(intersection_point, s1, s2));
}
