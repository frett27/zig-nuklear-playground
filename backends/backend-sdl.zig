const nk = @import("zig-nuklear");
const std = @import("std");
const backends = @import("backends.zig");

pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
    @cInclude("SDL2/SDL_image.h");
    @cInclude("sdl2_gfx/SDL2_gfxPrimitives.h");
});

pub fn checkSDLError(sdlReturn: c_int) !void {
    std.debug.assert(sdlReturn == 0);
}

pub fn initSDL() !void {

    // SDL setup
    try checkSDLError(SDL_Init(SDL_INIT_VIDEO));
    try checkSDLError(TTF_Init());
    try checkSDLError(IMG_Init(0));
}

pub fn deinitSDL() !void {
    IMG_Quit();
    TTF_Quit();
    SDL_Quit();
}

pub const Backend = comptime {
    return try backends.createBackEnd(Driver, SDL_Window); 
};

pub fn init(allocator: *std.mem.Allocator) !*Backend {

    try initSDL();
    
    const winPtr = try createWindow(800,600);
    const d = try Driver.init(allocator, winPtr);
    
    const b = try allocator.create(Backend);
    
    b._loadImage = &Driver.loadImage;
    b._freeImage = &Driver.freeImage;

    b._createWindow = &createWindow;

    b._render = &Driver.render;
    b._handleAllCurrentEvents = &Driver.handleAllCurrentEvents;
    
    try b.wrap(d,winPtr);

    return b;
}

////////////////////////////////////////////////////////////////////

var default_atlas: nk.FontAtlas = undefined;
var default_font: ?*nk.UserFont = null;

fn createDefaultFont(allocator: *std.mem.Allocator) !*nk.UserFont {
    if (default_font) |res|
        return res;

    default_atlas = nk.atlas.init(allocator);
    default_font = &(try nk.atlas.addDefault(&default_atlas, 13, null)).handle;
    _ = try nk.atlas.bake(&default_atlas, .NK_FONT_ATLAS_RGBA32);
    nk.atlas.end(&default_atlas, .{ .id = 0 }, null);
    const f = default_font.?;

    return default_font.?;
}


////////////////////////////////////////////////////////////////////
// SDL Specific functions

pub fn createWindow(w: u32, h:u32) anyerror!*SDL_Window {
    var win = if (SDL_CreateWindow("Demo", SDL_WINDOWPOS_CENTERED, 
        SDL_WINDOWPOS_CENTERED, @intCast(c_int,w),@intCast(c_int, h), SDL_WINDOW_SHOWN |
        SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_RESIZABLE)) |curwin| curwin else unreachable;

    return win;
}

fn toDegree(a: f32) i16 {
    return @floatToInt(i16, a + std.math.pi / 2.0 * 90.0 / std.math.pi);
}

//
// Driver structure maintain the drawing context, with an associated window
//
// nk context is not part of the driver
//
pub const Driver = struct {

    const Self = @This();

    renderer: *SDL_Renderer = undefined,

    font: *TTF_Font = undefined,

    allocator: *std.mem.Allocator = undefined,

    pub fn init(allocator: *std.mem.Allocator, win: *SDL_Window) !*Self {
        const self = try allocator.create(Self);

        self.allocator = allocator;

        self.renderer = if (SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED)) |r| r else unreachable;
        self.font = if (TTF_OpenFont("/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf", 13)) |font| font else unreachable;

        return self;
    }

    pub fn loadImage(self: *Self, file: [*c]const u8) anyerror!nk.Image {
        var img: ?*SDL_Texture = IMG_LoadTexture(self.renderer, file);
        if (img) |i| {
            return nk.rest.nkImagePtr(i);
        }
        return error.error_loading_image;
    }

    pub fn freeImage(self: *Self, image: nk.Image) anyerror!void {
        if (image.handle.ptr) |ptr| {
            SDL_DestroyTexture(@ptrCast(*SDL_Texture,ptr));
            
        }
    }

    pub fn render(self: *Self, ctx: *nk.Context, win: *SDL_Window) anyerror!void {
        var width: c_int = 0;
        var height: c_int = 0;

        SDL_GetWindowSize(win, &width, &height);

        const renderer = self.renderer;

        // reset clip
        try checkSDLError(SDL_RenderSetClipRect(renderer, null));

        // clear
        const backgroundColor = ctx.style.window.background;
        try checkSDLError(SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0));

        try checkSDLError(SDL_RenderClear(renderer));

        // handle draw commands
        if (ctx.*.memory.size > 0) {
            var itCommands = nk.iterator(ctx);

            while (itCommands.next()) |command| {
                switch (command) {
                    .scissor => {

                        // clip region
                        const scissor = command.scissor;
                        var rect: SDL_Rect = .{ .x = scissor.x, .y = scissor.y, .w = scissor.w, .h = scissor.h };

                        try checkSDLError(SDL_RenderSetClipRect(renderer, &rect));
                    },
                    .line => {

                        // ToDo handle l->line_thickness
                        const line = command.line;
                        const color = line.color;

                        try checkSDLError(SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));

                        try checkSDLError(SDL_RenderDrawLine(renderer, line.*.begin.x, line.*.begin.y, line.*.end.x, line.*.end.y));
                    },
                    .curve => {

                        // ToDo handle l->line_thickness
                        const curve = command.curve;
                        const color = curve.color;
                        // try checkSDLError(SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));

                        const n = 4;
                        var vx: []Sint16 = try self.allocator.alloc(Sint16, n);
                        defer self.allocator.free(vx);
                        var vy: []Sint16 = try self.allocator.alloc(Sint16, n);
                        defer self.allocator.free(vy);

                        vx[0] = @intCast(Sint16, curve.begin.x);
                        vy[0] = @intCast(Sint16, curve.begin.y);

                        vx[1] = @intCast(Sint16, curve.ctrl[0].x);
                        vy[1] = @intCast(Sint16, curve.ctrl[0].y);

                        vx[2] = @intCast(Sint16, curve.ctrl[1].x);
                        vy[2] = @intCast(Sint16, curve.ctrl[1].y);

                        vx[3] = @intCast(Sint16, curve.end.x);
                        vy[3] = @intCast(Sint16, curve.end.y);

                        try checkSDLError(bezierRGBA(renderer, &vx[0], &vy[0], n, 2, color.r, color.g, color.b, color.a));
                    },
                    .rect => {

                        // ToDo handle l->line_thickness
                        const rect = command.rect;
                        const color = rect.color;
                        try checkSDLError(SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));

                        var r = SDL_Rect{
                            .x = rect.x,
                            .y = rect.y,
                            .h = rect.h,
                            .w = rect.w,
                        };

                        try checkSDLError(roundedRectangleRGBA(renderer, rect.x, rect.y, rect.x + @intCast(c_short, rect.w), rect.y + @intCast(c_short, rect.h), @intCast(i16, rect.rounding), color.r, color.g, color.b, color.a));
                    },
                    .rect_filled => {

                        // ToDo handle (unsigned short)r->rounding
                        const rect_filled = command.rect_filled;
                        const color = rect_filled.*.color;

                        try checkSDLError(roundedBoxRGBA(renderer, rect_filled.x, rect_filled.y, rect_filled.x + @intCast(c_short, rect_filled.w), rect_filled.y + @intCast(c_short, rect_filled.h), @intCast(i16, rect_filled.rounding), color.r, color.g, color.b, color.a));
                    },
                    .rect_multi_color => {},
                    .circle => {

                        // ToDo handle l->line_thickness
                        const circle = command.circle;

                        const color = circle.color;
                        try checkSDLError(SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));

                        var tab: [11]SDL_Point = undefined;
                        for ([_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }) |indice| {
                            tab[indice] = .{
                                .x = @floatToInt(c_short, @intToFloat(f32, @intCast(c_short, circle.x) + @divFloor(@intCast(c_short, circle.w), 2)) + @intToFloat(f32, circle.w) / 2.0 * std.math.cos(2 * std.math.pi / 9.0 * @intToFloat(f32, indice))),
                                .y = @floatToInt(c_short, @intToFloat(f32, @intCast(c_short, circle.y) + @divFloor(@intCast(c_short, circle.h), 2)) + @intToFloat(f32, circle.h) / 2.0 * std.math.sin(2 * std.math.pi / 9.0 * @intToFloat(f32, indice))),
                            };
                        }

                        try checkSDLError(SDL_RenderDrawLines(renderer, @ptrCast([*c]SDL_Point, &tab[0]), 10));
                    },
                    .circle_filled => {
                        const circle = command.circle_filled;
                        const color = circle.color;
                        try checkSDLError(filledEllipseRGBA(renderer, circle.x + @intCast(c_short, circle.w / 2), circle.y + @intCast(c_short, circle.h / 2), @intCast(i16, circle.w / 2), @intCast(i16, circle.h / 2), color.r, color.g, color.b, color.a));
                    },
                    .arc => {
                        const arc = command.arc;
                        const color = arc.color;

                        try checkSDLError(pieRGBA(renderer, arc.cx, arc.cy, @intCast(Sint16, arc.r), toDegree(arc.a[0]), toDegree(arc.a[1]), color.r, color.g, color.b, color.a));
                    },

                    .arc_filled => {
                        const arc = command.arc_filled;
                        const color = arc.color;

                        try checkSDLError(filledPieRGBA(renderer, arc.cx, arc.cy, @intCast(Sint16, arc.r), toDegree(arc.a[0]), toDegree(arc.a[1]), color.r, color.g, color.b, color.a));
                    },
                    .triangle => {

                        // ToDo handle l->line_thickness
                        const t = command.triangle_filled;

                        try checkSDLError(aatrigonRGBA(renderer, @intCast(Sint16, t.a.x), @intCast(Sint16, t.a.y), @intCast(Sint16, t.b.x), @intCast(Sint16, t.b.y), @intCast(Sint16, t.c.x), @intCast(Sint16, t.c.y), t.color.r, t.color.g, t.color.b, t.color.a));
                    },
                    .triangle_filled => {
                        const t = command.triangle_filled;

                        try checkSDLError(filledTrigonRGBA(renderer, @intCast(Sint16, t.a.x), @intCast(Sint16, t.a.y), @intCast(Sint16, t.b.x), @intCast(Sint16, t.b.y), @intCast(Sint16, t.c.x), @intCast(Sint16, t.c.y), t.color.r, t.color.g, t.color.b, t.color.a));
                    },
                    .polygon => {

                        // ToDo handle l->line_thickness

                        const p = command.polygon;
                        const color = p.color;

                        const colori: Uint32 = @as(u32, color.r) | @as(u32, color.g) << 8 | @as(u32, color.g) << 16 | @as(u32, color.a) << 24;

                        // convert points
                        var i: u32 = 0;
                        var n = p.point_count;

                        var vx: []Sint16 = try self.allocator.alloc(Sint16, n);
                        defer self.allocator.free(vx);
                        var vy: []Sint16 = try self.allocator.alloc(Sint16, n);
                        defer self.allocator.free(vy);

                        while (i < p.point_count) {
                            vx[i] = @intCast(Sint16, p.points[i].x);
                            vy[i] = @intCast(Sint16, p.points[i].y);
                            i += 1;
                        }

                        try checkSDLError(aapolygonRGBA(renderer, &vx[0], &vy[0], n, color.r, color.g, color.b, color.a));
                    },
                    .polygon_filled => {
                        const p = command.polygon_filled;
                        const color = p.color;

                        const colori: Uint32 = @as(u32, color.r) | @as(u32, color.g) << 8 | @as(u32, color.g) << 16 | @as(u32, color.a) << 24;

                        // convert points
                        var i: u32 = 0;
                        var n = p.point_count;

                        var vx: []Sint16 = try self.allocator.alloc(Sint16, n);
                        defer self.allocator.free(vx);
                        var vy: []Sint16 = try self.allocator.alloc(Sint16, n);
                        defer self.allocator.free(vy);

                        while (i < p.point_count) {
                            vx[i] = @intCast(Sint16, p.points[i].x);
                            vy[i] = @intCast(Sint16, p.points[i].y);
                            i += 1;
                        }

                        try checkSDLError(filledPolygonRGBA(renderer, &vx[0], &vy[0], n, color.r, color.g, color.b, color.a));
                    },
                    .polyline => {

                        // case NK_COMMAND_POLYLINE: {
                        //     const struct nk_command_polyline *p = (const struct nk_command_polyline *)cmd;
                        //     nk_xsurf_stroke_polyline(surf, p->points, p->point_count, p->line_thickness, p->color);
                        // } break;

                        const p = command.polyline;
                        const color = p.color;

                        var i: u32 = 1;
                        var n = p.point_count;
                        while (i < n) {
                            try checkSDLError(aalineRGBA(renderer, p.points[i - 1].x, p.points[i - 1].y, p.points[i].x, p.points[i].y, color.r, color.g, color.b, color.a));

                            i += 1;
                        }
                    },
                    .text => {
                        const text = command.text;
                        const color = text.foreground;
                        const bgcolor = text.background;
                        const surface = TTF_RenderUTF8_Blended(self.font, &text.string, .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a });
                        defer SDL_FreeSurface(surface);

                        // now you can convert it into a texture
                        const texture: *SDL_Texture = if (SDL_CreateTextureFromSurface(renderer, surface)) |t| t else unreachable;
                        defer SDL_DestroyTexture(texture);
                        var format: Uint32 = 0;
                        var access: c_int = 0;
                        var w: c_int = 0;
                        var h: c_int = 0;
                        try checkSDLError(SDL_QueryTexture(texture, &format, &access, &w, &h));

                        const srect: SDL_Rect = .{
                            .x = 0,
                            .y = 0,
                            .h = h,
                            .w = w,
                        };
                        const rect: SDL_Rect = .{
                            .x = text.x,
                            .y = text.y,
                            .h = h,
                            .w = w,
                        };

                        try checkSDLError(SDL_RenderCopy(renderer, texture, null, &rect));
                    },
                    .image => {
                        // case NK_COMMAND_IMAGE: {
                        //     const struct nk_command_image *i = (const struct nk_command_image *)cmd;
                        //     nk_xsurf_draw_image(surf, i->x, i->y, i->w, i->h, i->img, i->col);
                        // } break;

                        const image = command.image;
                        const color = image.col;

                        const drect: SDL_Rect = .{
                            .x = image.x,
                            .y = image.y,
                            .h = image.h,
                            .w = image.w,
                        };

                        if (image.img.handle.ptr) |ptr| {
                            try checkSDLError(SDL_RenderCopy(renderer, @ptrCast(*SDL_Texture, @alignCast(@alignOf(*SDL_Texture), ptr)), null, &drect));
                        }
                    },
                    .custom => {},

                    // case NK_COMMAND_RECT_MULTI_COLOR:
                    // case NK_COMMAND_CUSTOM:
                    // default: break;
                    // }

                }
            } // while
        }

        nk.clear(ctx);

        SDL_RenderPresent(self.renderer);
    }

    pub fn handleAllCurrentEvents(self: *Self,  ctx: *nk.Context, win: *SDL_Window) anyerror!bool {

        // Input handling
        var evt: SDL_Event = undefined;
        nk.input.begin(ctx);
        while (SDL_PollEvent(&evt) > 0) {
            if (evt.type == SDL_QUIT) return false;
            _ = try self.handleEvent(win, ctx, &evt);
        }
        nk.input.end(ctx);

        return true; // continue
    }

    fn handleEvent(self: *Self, win: *SDL_Window, ctx: *nk.Context, evt: *SDL_Event) !i32 {

        // optional grabbing behavior
        if (ctx.*.input.mouse.grab != 0) {
            try checkSDLError(SDL_SetRelativeMouseMode(SDL_bool.SDL_TRUE));
            ctx.*.input.mouse.grab = 0;
        } else if (ctx.*.input.mouse.ungrab != 0) {
            var x = ctx.*.input.mouse.prev.x;
            var y = ctx.*.input.mouse.prev.y;
            try checkSDLError(SDL_SetRelativeMouseMode(SDL_bool.SDL_FALSE));
            SDL_WarpMouseInWindow(win, @floatToInt(c_int, x), @floatToInt(c_int, y));
            ctx.*.input.mouse.ungrab = 0;
        }

        if (evt.*.type == SDL_KEYUP or evt.*.type == SDL_KEYDOWN) {
            // key events
            var down = (evt.*.type == SDL_KEYDOWN);
            const state = SDL_GetKeyboardState(0);
            const sym = evt.*.key.keysym.sym;
            if (sym == SDLK_RSHIFT or sym == SDLK_LSHIFT) {
                nk.input.key(ctx, nk.Keys.NK_KEY_SHIFT, down);
            } else if (sym == SDLK_DELETE) {
                nk.input.key(ctx, nk.Keys.NK_KEY_DEL, down);
            } else if (sym == SDLK_RETURN) {
                nk.input.key(ctx, nk.Keys.NK_KEY_ENTER, down);
            } else if (sym == SDLK_TAB) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TAB, down);
            } else if (sym == SDLK_BACKSPACE) {
                nk.input.key(ctx, nk.Keys.NK_KEY_BACKSPACE, down);
            } else if (sym == SDLK_HOME) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_START, down);
                nk.input.key(ctx, nk.Keys.NK_KEY_SCROLL_START, down);
            } else if (sym == SDLK_END) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_END, down);
                nk.input.key(ctx, nk.Keys.NK_KEY_SCROLL_END, down);
            } else if (sym == SDLK_PAGEDOWN) {
                nk.input.key(ctx, nk.Keys.NK_KEY_SCROLL_DOWN, down);
            } else if (sym == SDLK_PAGEUP) {
                nk.input.key(ctx, nk.Keys.NK_KEY_SCROLL_UP, down);
            } else if (sym == SDLK_z) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_UNDO, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_r) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_REDO, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_c) {
                nk.input.key(ctx, nk.Keys.NK_KEY_COPY, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_v) {
                nk.input.key(ctx, nk.Keys.NK_KEY_PASTE, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_x) {
                nk.input.key(ctx, nk.Keys.NK_KEY_CUT, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_b) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_LINE_START, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_e) {
                nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_LINE_END, down and (state[SDL_SCANCODE_LCTRL] != 0));
            } else if (sym == SDLK_UP) {
                nk.input.key(ctx, nk.Keys.NK_KEY_UP, down);
            } else if (sym == SDLK_DOWN) {
                nk.input.key(ctx, nk.Keys.NK_KEY_DOWN, down);
            } else if (sym == SDLK_LEFT) {
                if (state[SDL_SCANCODE_LCTRL] != 0) {
                    nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_WORD_LEFT, down);
                } else nk.input.key(ctx, nk.Keys.NK_KEY_LEFT, down);
            } else if (sym == SDLK_RIGHT) {
                if (state[SDL_SCANCODE_LCTRL] != 0) {
                    nk.input.key(ctx, nk.Keys.NK_KEY_TEXT_WORD_RIGHT, down);
                } else nk.input.key(ctx, nk.Keys.NK_KEY_RIGHT, down);
            } else {
                return 0;
            }

            return 1;
        } else if (evt.*.type == SDL_MOUSEBUTTONDOWN or evt.*.type == SDL_MOUSEBUTTONUP) {
            // mouse button
            const down = evt.*.type == SDL_MOUSEBUTTONDOWN; // int
            const x = evt.*.button.x;
            const y = evt.*.button.y;
            if (evt.*.button.button == SDL_BUTTON_LEFT) {
                if (evt.*.button.clicks > 1) {
                    nk.input.button(ctx, nk.input.Buttons.NK_BUTTON_DOUBLE, x, y, down);
                }
                nk.input.button(ctx, nk.input.Buttons.NK_BUTTON_LEFT, x, y, down);
            } else if (evt.*.button.button == SDL_BUTTON_MIDDLE) {
                nk.input.button(ctx, nk.input.Buttons.NK_BUTTON_MIDDLE, x, y, down);
            } else if (evt.*.button.button == SDL_BUTTON_RIGHT) {
                nk.input.button(ctx, nk.input.Buttons.NK_BUTTON_RIGHT, x, y, down);
            }
            return 1;
        } else if (evt.*.type == SDL_MOUSEMOTION) {
            // mouse motion
            if (ctx.*.input.mouse.grabbed != 0) {
                const x = ctx.*.input.mouse.prev.x;
                const y = ctx.*.input.mouse.prev.y;
                nk.input.motion(ctx, @floatToInt(c_int, x) + evt.*.motion.xrel, @floatToInt(c_int, y) + evt.*.motion.yrel);
            } else nk.input.motion(ctx, evt.*.motion.x, evt.*.motion.y);
            return 1;
        } else if (evt.*.type == SDL_TEXTINPUT) {
            // text input */
            var glyph = [4]u8{ 0, 0, 0, 0 };
            _ = memcpy(&glyph, @ptrCast(*const c_void, &evt.*.text.text), nk.utf_size);
            nk.input.glyph(ctx, glyph);
            return 1;
        } else if (evt.*.type == SDL_MOUSEWHEEL) {
            // mouse wheel
            nk.input.scroll(ctx, nk.vec2(@intToFloat(f32, evt.*.wheel.x), @intToFloat(f32, evt.*.wheel.y))); // (float)
            return 1;
        }

        return 0;
    }
};

test {
    std.testing.refAllDecls(@This());
}
