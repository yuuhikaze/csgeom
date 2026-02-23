const std = @import("std");
const set = @import("ziglangSet");
const lib = @import("lib");
const geom = lib.geometry;

pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const Renderer = struct {
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
    arena_dimensions: ArenaDimensions,

    const ArenaDimensions = struct { scale: f32, offset_x: f32, offset_y: f32 };

    pub fn init(window_title: []const u8) !Renderer {
        // Initialize SDL
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            std.debug.print("SDL initialization failed: {s}\n", .{sdl.SDL_GetError()});
            return error.SDLInitFailed;
        }
        errdefer sdl.SDL_Quit();

        // Request 4 samples for MSAA (Multisample Anti-Aliasing)
        _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_MULTISAMPLESAMPLES, 4);

        // Create window
        const window = sdl.SDL_CreateWindow(window_title.ptr, 800, 600, sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY // Ensures crispness on Retina/4K screens
        ) orelse {
            std.debug.print("Window creation failed: {s}\n", .{sdl.SDL_GetError()});
            return error.WindowCreationFailed;
        };
        errdefer sdl.SDL_DestroyWindow(window);

        // Create renderer
        const renderer = sdl.SDL_CreateRenderer(window, null) orelse {
            std.debug.print("Renderer creation failed: {s}\n", .{sdl.SDL_GetError()});
            return error.RendererCreationFailed;
        };

        return Renderer{
            .window = window,
            .renderer = renderer,
            .arena_dimensions = .{ .scale = 1.0, .offset_x = 0.0, .offset_y = 0.0 },
        };
    }

    pub fn deinit(self: *Renderer) void {
        sdl.SDL_DestroyRenderer(self.renderer);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    /// Create arena (100x100 responsive board)
    pub fn createArena(self: *Renderer) void {
        _ = sdl.SDL_SetRenderDrawBlendMode(self.renderer, sdl.SDL_BLENDMODE_BLEND);
        // Get current window size
        var window_w: c_int = undefined;
        var window_h: c_int = undefined;
        _ = sdl.SDL_GetWindowSize(self.window, &window_w, &window_h);

        // Compute bounding box dimensions to preserve 1:1 aspect ratio
        const square_size = @min(window_w, window_h);
        self.arena_dimensions.scale = @as(f32, @floatFromInt(square_size)) / 100.0;

        // Center the bounding box in window
        self.arena_dimensions.offset_x = @as(f32, @floatFromInt(window_w - square_size)) / 2.0;
        self.arena_dimensions.offset_y = @as(f32, @floatFromInt(window_h - square_size)) / 2.0;

        // Clear screen, set background to white
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255);
        _ = sdl.SDL_RenderClear(self.renderer);
    }

    /// Render points
    pub fn renderPoints(self: *Renderer, points: set.Set(geom.Point), rgb: anytype) !void {
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, rgb.@"0", rgb.@"1", rgb.@"2", 255);
        var point_it = points.iterator();
        while (point_it.next()) |p| {
            const scaled_x = @as(f32, @floatFromInt(p.x)) * self.arena_dimensions.scale + self.arena_dimensions.offset_x;
            const scaled_y = @as(f32, @floatFromInt(p.y)) * self.arena_dimensions.scale + self.arena_dimensions.offset_y;

            const rect = sdl.SDL_FRect{
                .x = scaled_x - 2.0,
                .y = scaled_y - 2.0,
                .w = 4.0,
                .h = 4.0,
            };
            _ = sdl.SDL_RenderFillRect(self.renderer, &rect);
        }
    }

    /// Render edges (red)
    pub fn renderEdges(self: *Renderer, edges: set.Set(geom.Edge), rgb: anytype) !void {
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, rgb.@"0", rgb.@"1", rgb.@"2", 255);
        var edge_it = edges.iterator();
        while (edge_it.next()) |edge| {
            const x1 = @as(f32, @floatFromInt(edge.from.x)) * self.arena_dimensions.scale + self.arena_dimensions.offset_x;
            const y1 = @as(f32, @floatFromInt(edge.from.y)) * self.arena_dimensions.scale + self.arena_dimensions.offset_y;
            const x2 = @as(f32, @floatFromInt(edge.to.x)) * self.arena_dimensions.scale + self.arena_dimensions.offset_x;
            const y2 = @as(f32, @floatFromInt(edge.to.y)) * self.arena_dimensions.scale + self.arena_dimensions.offset_y;

            _ = sdl.SDL_RenderLine(self.renderer, x1, y1, x2, y2);
        }
    }

    /// Present renderer
    pub fn present(self: *Renderer) void {
        _ = sdl.SDL_RenderPresent(self.renderer);
    }

    pub fn handleEvents(self: *Renderer) bool {
        _ = self;
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            if (event.type == sdl.SDL_EVENT_QUIT) {
                return true; // quit requested
            }
        }
        return false; // continue running
    }
};
