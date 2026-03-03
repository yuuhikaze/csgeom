const std = @import("std");
const set = @import("ziglangSet");
const lib = @import("lib");
const geom = lib.geometry;
const geo = lib.geo;
const enclosing = lib.enclosing_circle;
const convex = lib.convex_hull;
const repositories = @import("repositories");
const mem = repositories.memory;
const rdr = @import("renderer");

// Embedded Quito parishes data (from INEC Ecuador)
const QUITO_PARISHES_CSV =
    \\name,lat,lon
    \\ALANGASI,-0.302910,-78.424910
    \\AMAGUAÑA,-0.365552,-78.488169
    \\ATAHUALPA (HABASPAMBA),0.147229,-78.355912
    \\CALACALI,0.055893,-78.515110
    \\CALDERON (CARAPUNGO),-0.085923,-78.427740
    \\CONOCOTO,-0.281118,-78.476345
    \\CUMBAYA,-0.201507,-78.432096
    \\CHAVEZPAMBA,0.126263,-78.404249
    \\CHECA (CHILPA),-0.150876,-78.280694
    \\EL QUINCHE,-0.124082,-78.258394
    \\GUALEA,0.116183,-78.769327
    \\GUANGOPOLO,-0.252956,-78.440059
    \\GUAYLLABAMBA,-0.052894,-78.342793
    \\LA MERCED,-0.295199,-78.394793
    \\LLANO CHICO,-0.127706,-78.446243
    \\LLOA,-0.201095,-78.703259
    \\NANEGAL,0.120456,-78.648038
    \\NANEGALITO,0.052176,-78.708553
    \\NAYON,-0.165019,-78.437797
    \\NONO,-0.047822,-78.599890
    \\PACTO,0.161157,-78.853020
    \\PERUCHO,0.114107,-78.417784
    \\PIFO,-0.273774,-78.307995
    \\PINTAG,-0.364908,-78.358207
    \\POMASQUI,-0.055224,-78.462924
    \\PUELLARO,0.067564,-78.391969
    \\PUEMBO,-0.167836,-78.371168
    \\SAN ANTONIO,0.040501,-78.437911
    \\SAN JOSE DE MINAS,0.187678,-78.492109
    \\TABABELA,-0.151679,-78.354694
    \\TUMBACO,-0.204898,-78.395692
    \\YARUQUI,-0.179213,-78.307946
    \\ZAMBIZA,-0.146981,-78.419167
    \\QUITO,-0.181946,-78.478374
;

pub fn runAntennaQuito() !void {
    const allocator = mem.allocator;

    // 1. Load embedded CSV data
    std.debug.print("Loading Quito parish data...\n", .{});
    const csv_data = QUITO_PARISHES_CSV;

    // 2. Parse parishes
    var parishes = try geo.parseParroquiasCsv(allocator, csv_data);
    defer {
        for (parishes.items) |p| {
            allocator.free(p.name);
        }
        parishes.deinit(allocator);
    }

    std.debug.print("Loaded {d} parishes\n", .{parishes.items.len});

    // 3. Convert to local km coordinates
    var km_points: std.ArrayList(struct { x: f64, y: f64, name: []const u8 }) = .empty;
    defer km_points.deinit(allocator);

    var min_x: f64 = std.math.inf(f64);
    var max_x: f64 = -std.math.inf(f64);
    var min_y: f64 = std.math.inf(f64);
    var max_y: f64 = -std.math.inf(f64);

    for (parishes.items) |p| {
        const km = geo.latLonToKm(p.lat, p.lon);
        try km_points.append(allocator, .{ .x = km.x, .y = km.y, .name = p.name });
        min_x = @min(min_x, km.x);
        max_x = @max(max_x, km.x);
        min_y = @min(min_y, km.y);
        max_y = @max(max_y, km.y);
    }

    // 4. Scale to 0-100 for renderer (with margin)
    const range_x = max_x - min_x;
    const range_y = max_y - min_y;
    const range = @max(range_x, range_y);
    const margin = 5.0;
    const scale = (100.0 - 2.0 * margin) / range;

    var points_set = set.Set(geom.Point).init(allocator);
    defer points_set.deinit();

    for (km_points.items) |p| {
        const scaled_x: i32 = @intFromFloat((p.x - min_x) * scale + margin);
        const scaled_y: i32 = @intFromFloat((p.y - min_y) * scale + margin);
        _ = try points_set.add(geom.Point{ .x = scaled_x, .y = scaled_y });
    }

    // 5. Compute minimum enclosing circle
    std.debug.print("\nComputing minimum enclosing circle (Welzl)...\n", .{});
    const circle = try enclosing.computeWelzl(allocator, points_set);

    // Convert circle center back to km then lat/lon
    const center_km_x = (circle.center.x - margin) / scale + min_x;
    const center_km_y = (circle.center.y - margin) / scale + min_y;
    const radius_km = circle.radius / scale;
    const center_latlon = geo.kmToLatLon(center_km_x, center_km_y);

    // 6. Compute convex hull
    std.debug.print("Computing convex hull (Graham Scan)...\n", .{});
    var hull = try convex.computeGraham(allocator, points_set);
    defer hull.deinit();

    // 7. Calculate areas
    const circle_area_km2 = std.math.pi * radius_km * radius_km;

    // Get hull vertices for area calculation (must be in polygon order for shoelace)
    var hull_vertices_x: std.ArrayList(f64) = .empty;
    defer hull_vertices_x.deinit(allocator);
    var hull_vertices_y: std.ArrayList(f64) = .empty;
    defer hull_vertices_y.deinit(allocator);

    // Walk hull edges in order to get vertices in polygon order
    var hull_it = hull.iterator();
    if (hull_it.next()) |first_edge| {
        var current = first_edge.from;
        const start = current;

        // Add first vertex
        var km_x = (@as(f64, @floatFromInt(current.x)) - margin) / scale + min_x;
        var km_y = (@as(f64, @floatFromInt(current.y)) - margin) / scale + min_y;
        try hull_vertices_x.append(allocator, km_x);
        try hull_vertices_y.append(allocator, km_y);

        current = first_edge.to;

        // Walk until we return to start
        while (current.x != start.x or current.y != start.y) {
            km_x = (@as(f64, @floatFromInt(current.x)) - margin) / scale + min_x;
            km_y = (@as(f64, @floatFromInt(current.y)) - margin) / scale + min_y;
            try hull_vertices_x.append(allocator, km_x);
            try hull_vertices_y.append(allocator, km_y);

            // Find next edge (edge.from == current)
            var inner_it = hull.iterator();
            while (inner_it.next()) |edge| {
                if (edge.from.x == current.x and edge.from.y == current.y) {
                    current = edge.to;
                    break;
                }
            }
        }
    }

    const hull_area_km2 = geo.shoelaceArea(hull_vertices_x.items, hull_vertices_y.items);
    const waste_percent = (circle_area_km2 - hull_area_km2) / circle_area_km2 * 100.0;

    // 8. Print report
    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║             ANTENNA PLACEMENT REPORT - QUITO           ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("  Parishes analyzed: {d}                                  \n", .{parishes.items.len});
    std.debug.print("  Optimal antenna center:                                 \n", .{});
    std.debug.print("    Latitude:  {d:>10.6}°                                 \n", .{center_latlon.lat});
    std.debug.print("    Longitude: {d:>10.6}°                                 \n", .{center_latlon.lon});
    std.debug.print("  Coverage radius: {d:>8.2} km                            \n", .{radius_km});
    std.debug.print("══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  AREA COMPARISON                                         \n", .{});
    std.debug.print("    Circle area:      {d:>10.2} km²                       \n", .{circle_area_km2});
    std.debug.print("    Convex hull area: {d:>10.2} km²                       \n", .{hull_area_km2});
    std.debug.print("    Area waste:       {d:>10.2}%                          \n", .{waste_percent});
    std.debug.print("══════════════════════════════════════════════════════════\n", .{});

    // 9. Initialize renderer
    var renderer = try rdr.Renderer.init("Quito Antenna Network - Circle + Hull");
    defer renderer.deinit();

    // Render loop
    var quit = false;
    while (!quit) {
        quit = renderer.handleEvents();
        renderer.createArena();

        // Draw convex hull (red)
        try renderer.renderEdges(hull);

        // Draw minimum enclosing circle (blue)
        renderer.renderCircle(circle.center, circle.radius);

        // Draw parish points (black) - on top
        try renderer.renderPoints(points_set);

        renderer.present();
        rdr.sdl.SDL_Delay(16);
    }
}
