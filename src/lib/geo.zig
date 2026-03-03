const std = @import("std");

/// Geographic point with lat/lon in degrees
pub const GeoPoint = struct {
    lat: f64,
    lon: f64,
    name: []const u8,
};

/// Earth radius in km
const EARTH_RADIUS_KM: f64 = 6371.0;

/// Quito reference point for local coordinate system
const QUITO_REF_LAT: f64 = -0.18;
const QUITO_REF_LON: f64 = -78.47;

/// Parse CSV file with format: name,lat,lon
pub fn parseParroquiasCsv(allocator: std.mem.Allocator, csv_data: []const u8) !std.ArrayList(GeoPoint) {
    var points: std.ArrayList(GeoPoint) = .empty;
    errdefer {
        for (points.items) |p| {
            allocator.free(p.name);
        }
        points.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, csv_data, '\n');

    // Skip header
    _ = lines.next();

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var fields = std.mem.splitScalar(u8, line, ',');
        const name_raw = fields.next() orelse continue;
        const lat_str = fields.next() orelse continue;
        const lon_str = fields.next() orelse continue;

        const lat = std.fmt.parseFloat(f64, lat_str) catch continue;
        const lon = std.fmt.parseFloat(f64, lon_str) catch continue;

        // Duplicate name string so it persists
        const name = try allocator.dupe(u8, name_raw);

        try points.append(allocator, GeoPoint{
            .lat = lat,
            .lon = lon,
            .name = name,
        });
    }

    return points;
}

/// Convert lat/lon to local X/Y coordinates in km
/// Uses equirectangular projection centered on Quito
pub fn latLonToKm(lat: f64, lon: f64) struct { x: f64, y: f64 } {
    const lat_rad = lat * std.math.pi / 180.0;
    const lon_rad = lon * std.math.pi / 180.0;
    const ref_lat_rad = QUITO_REF_LAT * std.math.pi / 180.0;
    const ref_lon_rad = QUITO_REF_LON * std.math.pi / 180.0;

    // Equirectangular projection
    const x = EARTH_RADIUS_KM * (lon_rad - ref_lon_rad) * @cos(ref_lat_rad);
    const y = EARTH_RADIUS_KM * (lat_rad - ref_lat_rad);

    return .{ .x = x, .y = y };
}

/// Convert local X/Y coordinates (km) back to lat/lon
pub fn kmToLatLon(x: f64, y: f64) struct { lat: f64, lon: f64 } {
    const ref_lat_rad = QUITO_REF_LAT * std.math.pi / 180.0;
    const ref_lon_rad = QUITO_REF_LON * std.math.pi / 180.0;

    const lat_rad = y / EARTH_RADIUS_KM + ref_lat_rad;
    const lon_rad = x / (EARTH_RADIUS_KM * @cos(ref_lat_rad)) + ref_lon_rad;

    return .{
        .lat = lat_rad * 180.0 / std.math.pi,
        .lon = lon_rad * 180.0 / std.math.pi,
    };
}

/// Haversine distance between two points in km
pub fn haversineKm(p1: GeoPoint, p2: GeoPoint) f64 {
    const lat1 = p1.lat * std.math.pi / 180.0;
    const lat2 = p2.lat * std.math.pi / 180.0;
    const dlat = (p2.lat - p1.lat) * std.math.pi / 180.0;
    const dlon = (p2.lon - p1.lon) * std.math.pi / 180.0;

    const a = @sin(dlat / 2.0) * @sin(dlat / 2.0) +
        @cos(lat1) * @cos(lat2) * @sin(dlon / 2.0) * @sin(dlon / 2.0);
    const c = 2.0 * std.math.atan2(@sqrt(a), @sqrt(1.0 - a));

    return EARTH_RADIUS_KM * c;
}

/// Calculate area of a polygon using shoelace formula
/// Points should be in consistent coordinate units (e.g., km)
pub fn shoelaceArea(xs: []const f64, ys: []const f64) f64 {
    if (xs.len != ys.len or xs.len < 3) return 0;

    var area: f64 = 0;
    const n = xs.len;
    for (0..n) |i| {
        const j = (i + 1) % n;
        area += xs[i] * ys[j];
        area -= xs[j] * ys[i];
    }
    return @abs(area) / 2.0;
}

// Tests
test "latLonToKm round trip" {
    const lat: f64 = -0.25;
    const lon: f64 = -78.5;

    const km = latLonToKm(lat, lon);
    const back = kmToLatLon(km.x, km.y);

    try std.testing.expectApproxEqAbs(lat, back.lat, 0.0001);
    try std.testing.expectApproxEqAbs(lon, back.lon, 0.0001);
}

test "haversine known distance" {
    // Quito to a point ~10km north
    const p1 = GeoPoint{ .lat = -0.18, .lon = -78.47, .name = "A" };
    const p2 = GeoPoint{ .lat = -0.09, .lon = -78.47, .name = "B" }; // ~10km north

    const dist = haversineKm(p1, p2);
    try std.testing.expectApproxEqAbs(10.0, dist, 0.5);
}
