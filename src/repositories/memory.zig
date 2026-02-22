const std = @import("std");

pub var config: Config = .{};

pub const Config = struct {
    topic: AlgorithmFamilies = AlgorithmFamilies.ConvexHull,
    algo: Algorithms = Algorithms.Slow,
};

pub const AlgorithmFamilies = enum {
    ConvexHull,
};

pub const Algorithms = enum {
    Slow,
};

pub var init: std.process.Init = undefined;
pub var allocator: std.mem.Allocator = undefined;
