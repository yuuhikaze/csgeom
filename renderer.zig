const std = @import("std");
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

    pub fn renderPoints(self: *Renderer, points: std.AutoHashMap(geo.Point, void)) void {
        // Clear screen (white background)
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255);
        _ = sdl.SDL_RenderClear(self.renderer);

        // Draw points (black)
        _ = sdl.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        var point_it = points.keyIterator();
        while (point_it.next()) |p| {
            const rect = sdl.SDL_FRect{
                .x = @as(f32, @floatFromInt(p.x)) - 2.0,
                .y = @as(f32, @floatFromInt(p.y)) - 2.0,
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
