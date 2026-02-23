const std = @import("std");

pub var config: Config = .{};

pub const Config = struct {
    algorithm: Algorithm = Algorithm.ConvexHull,
    implementation: Implementation = Implementation.Slow,
};

pub const Algorithm = enum {
    ConvexHull,
    LineSweep,
};

pub const Implementation = enum {
    // ConvexHull
    Slow,
    // LineSweep
    TopToBottom,
};

pub var init: std.process.Init = undefined;
pub var allocator: std.mem.Allocator = undefined;
