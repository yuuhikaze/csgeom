const std = @import("std");

pub var config: Config = .{};

pub const Config = struct {
    algorithm: Algorithm = Algorithm.ConvexHull,
    implementation: Implementation = Implementation.Slow,
};

pub const Algorithm = enum {
    ConvexHull,
    SegmentIntersection,
    EnclosingCircle,
};

pub const Implementation = enum {
    Slow,
    GrahamScan,
    BentleyOttmann,
    Welzl,
};

pub var init: std.process.Init = undefined;
pub var allocator: std.mem.Allocator = undefined;
