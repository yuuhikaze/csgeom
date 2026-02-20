const std = @import("std");
const set = @import("ziglangSet");
const geo = @import("geometric-lib.zig");

pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const Renderer = struct {
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,

    pub fn init() !Renderer {
        // Initialize SDL
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            std.debug.print("SDL initialization failed: {s}\n", .{sdl.SDL_GetError()});
            return error.SDLInitFailed;
        }
        errdefer sdl.SDL_Quit();

        // Create window
        const window = sdl.SDL_CreateWindow(
            "Convex Hull Visualization",
            800,
            600,
            0,
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
        };
    }

    pub fn deinit(self: *Renderer) void {
        sdl.SDL_DestroyRenderer(self.renderer);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    pub fn renderPoints(self: *Renderer, points: set.Set(geo.Point)) void {
        // Get current window size
        var window_w: c_int = undefined;
        var window_h: c_int = undefined;
        _ = sdl.SDL_GetWindowSize(self.window, &window_w, &window_h);

        // Compute bounding box dimensions to preserve 1:1 aspect ratio
        const square_size = @min(window_w, window_h);
        const scale = @as(f32, @floatFromInt(square_size)) / 100.0;

        // Center the bounding box in window
        const offset_x = @as(f32, @floatFromInt(window_w - square_size)) / 2.0;
        const offset_y = @as(f32, @floatFromInt(window_h - square_size)) / 2.0;

        // Clear screen, set background to white
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255);
        _ = sdl.SDL_RenderClear(self.renderer);

        // Draw points (black)
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        var point_it = points.iterator();
        while (point_it.next()) |p| {
            const scaled_x = @as(f32, @floatFromInt(p.x)) * scale + offset_x;
            const scaled_y = @as(f32, @floatFromInt(p.y)) * scale + offset_y;

            const rect = sdl.SDL_FRect{
                .x = scaled_x - 2.0,
                .y = scaled_y - 2.0,
                .w = 4.0,
                .h = 4.0,
            };
            _ = sdl.SDL_RenderFillRect(self.renderer, &rect);
        }

        // Present renderer
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
