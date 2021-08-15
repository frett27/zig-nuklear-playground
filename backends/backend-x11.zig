const nk = @import("zig-nuklear");
const std = @import("std");

const backends = @import("backends.zig");

const x11 = @cImport({
    @cInclude("X11/Xlib.h");
});

const libc = @cImport({
    @cInclude("stdlib.h");
    @cInclude("sys/time.h");
    
});

pub fn initX11() !void {}

//////////////////////////////////////////////////////////
// X11 functions

const XFont = struct {
    ascent: i32,
    descent: i32,
    height: i32,
    set: x11.XFontSet,
    xfont: ?*x11.XFontStruct,
    handle: nk.UserFont,
};

const XSurface = struct {
    // graphic context
    gc: x11.GC,

    // display
    dpy: *x11.Display,

    screen: i32,

    drawable: x11.Drawable,

    w: u32,
    h: u32,

    // attributes associated to current win

win: x11.Window,
    vis: *x11.Visual,
    cmap: x11.Colormap,
    attr: x11.XWindowAttributes,
    swa: x11.XSetWindowAttributes,

    font: *XFont,

    wm_delete_window: x11.Atom,

    width: u32,
    height: u32,
};
const XImageWithAlpha = struct {
    ximage: *x11.XImage,
    clipMaskGC: x11.GC,
    clipMask: x11.Pixmap,
};

pub const Backend = comptime {
    return try backends.createBackEnd(Driver, XSurface);
};

pub fn init(allocator: *std.mem.Allocator) !*Backend {

    // init X11 client library
    const currentBackend = try allocator.create(Driver);

    const surf = try allocator.create(XSurface);
    currentBackend.surf = surf;

    surf.dpy = if (x11.XOpenDisplay(null)) |dpy| dpy else @panic("Could not open a display; perhaps $DISPLAY is not set?");

    var dpy = surf.dpy;

    surf.screen = x11.XDefaultScreen(dpy);

    //https://github.com/ziglang/zig/issues/5305

    const xpriv = std.meta.cast(x11._XPrivDisplay, dpy).*.screens[@intCast(usize, surf.screen)];
    const root = xpriv.root;

    currentBackend.dpy = dpy;
    currentBackend.root = root;

    // all this associated to xwindow

    surf.vis = x11.XDefaultVisual(dpy, surf.screen);
    surf.cmap = x11.XCreateColormap(dpy, currentBackend.root, surf.vis, x11.AllocNone);

    //

    surf.swa.colormap = surf.cmap;

    const WINDOW_WIDTH = 800;
    const WINDOW_HEIGHT = 600;

    surf.swa.event_mask =
        x11.ExposureMask | x11.KeyPressMask | x11.KeyReleaseMask |
        x11.ButtonPress | x11.ButtonReleaseMask | x11.ButtonMotionMask |
        x11.Button1MotionMask | x11.Button3MotionMask | x11.Button4MotionMask | x11.Button5MotionMask |
        x11.PointerMotionMask | x11.KeymapStateMask;

    surf.win = x11.XCreateWindow(currentBackend.dpy, currentBackend.root, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, x11.XDefaultDepth(surf.dpy, surf.screen), x11.InputOutput, surf.vis, x11.CWEventMask | x11.CWColormap, &surf.swa);

    _ = x11.XStoreName(surf.dpy, surf.win, "X11");
    _ = x11.XMapWindow(surf.dpy, surf.win);

    surf.wm_delete_window = x11.XInternAtom(surf.dpy, "WM_DELETE_WINDOW", 0);

    _ = x11.XSetWMProtocols(surf.dpy, surf.win, &surf.wm_delete_window, 1);

    // get window attributes
    _ = x11.XGetWindowAttributes(surf.dpy, surf.win, &surf.attr);

    surf.width = @intCast(u32, surf.attr.width);
    surf.height = @intCast(u32, surf.attr.height);

    // GUI
    surf.font = try xfontCreate(allocator, surf.dpy, "fixed");

    // ctx = nk_xlib_init(xw.font, xw.dpy, xw.screen, xw.win, xw.width, xw.height);

    // backend type
    const b = try allocator.create(Backend);

    // vtable
//     b._loadImage = &Driver.loadImage;
//     b._freeImage = &Driver.freeImage;

//     b._createWindow = &createWindow;

    b._render = &Driver.render;
    b._handleAllCurrentEvents = &Driver.handleAllCurrentEvents;

    try b.wrap(currentBackend, surf);

    return b;
}

fn xfontCreate(allocator: *std.mem.Allocator,dpy: *x11.Display, name: [*c]const u8) !*XFont {
    var ncount: c_int = 0;
    var def: [*c]u8 = undefined;
    var missing: [*c][*c]u8 = undefined;

    
    var font : *XFont = try allocator.create(XFont);

    font.set = x11.XCreateFontSet(dpy, name, &missing, &ncount, &def);
    var n : usize = @intCast(usize, ncount);

    if (missing != null) {
        while (n > 0) : (n -= 1)
            std.debug.print("missing fontset: {s}\n", .{missing[n]});
        x11.XFreeStringList(missing);
    }

    if (font.set != null) {
        var xfonts: [*]*x11.XFontStruct = undefined;
        var font_names: [*c][*c] u8 = undefined;
        _ = x11.XExtentsOfFontSet(font.set);
        n = @intCast(usize, x11.XFontsOfFontSet(font.set, @ptrCast([*c][*c][*c]x11.XFontStruct,&xfonts), &font_names));
        var i: usize = 0;
        while (n > 0) : (n -= 1) {
            font.ascent = std.math.max(font.ascent, xfonts[i].ascent);
            font.descent = std.math.max(font.descent, xfonts[i].descent);
            i += 1;
        }
    } else {
        font.xfont = x11.XLoadQueryFont(dpy, name);

        if (font.xfont == null) {
            font.xfont = x11.XLoadQueryFont(dpy, "fixed");
            if (font.xfont == null) {
                allocator.destroy(font);
                const Cannot_Allocate_Font = error {Error_Font_Loading}; 
                return Cannot_Allocate_Font.Error_Font_Loading;
            }
        }
        font.ascent = font.xfont.?.ascent;
        font.descent = font.xfont.?.descent;
    }
    font.height = font.ascent + font.descent;
    return font;
}

fn timeStamp() u64 {
    var tv: libc.timeval = undefined;
    if (libc.gettimeofday(&tv, null) < 0) return 0;
    return @intCast(u64,tv.tv_sec) * 1000 + @intCast(u64,@divTrunc(tv.tv_usec , 1000));
}

fn nk_color_from_byte(color: nk.Color) u64 {
    var res: u64 = 0;
    res |= @intCast(u32,color.r) << 16;
    res |= @intCast(u32,color.g) << 8;
    res |= @intCast(u32,color.b) << 0;
    return res;
}

fn nk_xsurf_clear(surf: *XSurface, color: nk.Color) void {
    _ = x11.XSetForeground(surf.dpy, surf.gc, nk_color_from_byte(color));
    _ = x11.XFillRectangle(surf.dpy, surf.drawable, surf.gc, 0, 0, surf.w, surf.h);
}

fn nk_xsurf_blit(target: Drawable, surf: *XSurface, w: u32, h: u32) void {
    x11.XCopyArea(surf.dpy, surf.drawable, target, surf.gc, 0, 0, w, h, 0, 0);
}

fn nk_xsurf_del(surf: *XSurface) void {
    x11.XFreePixmap(surf.dpy, surf.drawable);
    x11.XFreeGC(surf.dpy, surf.gc);
    x11.free(surf);
}

fn nk_xsurf_draw_image(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, img: nk.Image, col: nk.Color) void {
    XImageWithAlpha * aimage = @ptrCast(*XImageWithAlpha, img.handle.ptr);
    if (aimage) {
        if (aimage.clipMask) {
            XSetClipMask(surf.dpy, surf.gc, aimage.clipMask);
            XSetClipOrigin(surf.dpy, surf.gc, x, y);
        }
        XPutImage(surf.dpy, surf.drawable, surf.gc, aimage.ximage, 0, 0, x, y, w, h);
        XSetClipMask(surf.dpy, surf.gc, None);
    }
}

fn nk_xfont_get_text_width(handle: nk.handle, height: f32, text: []const u8, len: u32) f32 {
    const font: *XFont = @ptrCast(*XFont, handle.ptr);
    var r: XRectangle;
    if (!font or !text)
        return 0;

    if (font.set) {
        XmbTextExtents(font.set, text.ptr, len, NULL, &r);
        return @intAsFloat(f32, r.width);
    } else {
        var w = XTextWidth(font.xfont, text.ptr, len);
        return @intToFloat(f32, w);
    }
}

fn nk_xfont_del(dpy: *Display, font: *XFont) void {
    if (font == null) return;
    if (font.set != null) {
        XFreeFontSet(dpy, font.set);
    } else {
        XFreeFont(dpy, font.xfont);
    }
    free(font);
}

fn nk_xlib_set_font(ctx: *nk.Context, xfont: *XFont) void {
    const font: *nk_user_font = &xfont.handle;
    font.userdata = nk_handle_ptr(xfont);
    font.height = @intToFloat(f32, xfont.height);
    font.width = nk_xfont_get_text_width;
    nk_style_set_font(ctx, font);
}

fn nk_xlib_push_font(ctx: *nk.Context, xfont: *XFont) void {
    const font: *nk_user_font = &xfont.handle;
    font.userdata = nk_handle_ptr(xfont);
    font.height = @intToFloat(f32, xfont.height);
    font.width = nk_xfont_get_text_width;
    nk_style_push_font(ctx, font);
}

/////////////////////////////////////////////////////////////////
// draw facilities

fn nk_xsurf_scissor(surf: *XSurface, x: i16, y: i16, w: u16, h: u16) void {
    var clip_rect: x11.XRectangle = undefined;
    clip_rect.x = @intToFloat(f32,(x - 1));
    clip_rect.y = (y - 1);
    clip_rect.width = (w + 2);
    clip_rect.height = (h + 2);
    _ = x11.XSetClipRectangles(surf.dpy, surf.gc, 0, 0, &clip_rect, 1, x11.Unsorted);
}

fn nk_xsurf_stroke_line(surf: *XSurface, x0: i16, y0: i16, x1: i16, y1: i16, line_thickness: u32, col: nk.Color) void {
    var c: u64 = nk_color_from_byte(col);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, x11.JoinMiter);
    _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, x0, y0, x1, y1);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
}

fn nk_xsurf_stroke_rect(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, r: u16, line_thickness: u16, col: nk.Color) void {
    var c: u64 = nk_color_from_byte(col);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, x11.JoinMiter);
    if (r == 0) {
        _ = x11.XDrawRectangle(surf.dpy, surf.drawable, surf.gc, x, y, w, h);
        return;
    }

    {
        const xc = x + r;
        const yc = y + r;
        const wc = (w - 2 * r);
        const hc = (h - 2 * r);

        _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, xc, y, xc + wc, y);
        _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, x + w, yc, x + w, yc + hc);
        _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, xc, y + h, xc + wc, y + h);
        _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, x, yc, x, yc + hc);

        _ = x11.XDrawArc(surf.dpy, surf.drawable, surf.gc, xc + wc - r, y, r * 2, r * 2, 0 * 64, 90 * 64);
        _ = x11.XDrawArc(surf.dpy, surf.drawable, surf.gc, x, y, r * 2, r * 2, 90 * 64, 90 * 64);
        _ = x11.XDrawArc(surf.dpy, surf.drawable, surf.gc, x, yc + hc - r, r * 2, 2 * r, 180 * 64, 90 * 64);
        _ = x11.XDrawArc(surf.dpy, surf.drawable, surf.gc, xc + wc - r, yc + hc - r, r * 2, 2 * r, -90 * 64, 90 * 64);
    }
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, LineSolid, CapButt, JoinMiter);
}

fn nk_xsurf_fill_rect(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, r: u16, col: nk.Color) void {
    var c: u64 = nk_color_from_byte(col);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    if (r == 0) {
        _ = x11.XFillRectangle(surf.dpy, surf.drawable, surf.gc, x, y, w, h);
        return;
    }

    {
        const ir = @intCast(i16,r);
        const xc = x + ir;
        const yc = y + ir;
        const wc = @intCast(i16,(w - 2 * r));
        const hc = @intCast(i16,(h - 2 * r));

        var pnts: [12]x11.XPoint = undefined;
        pnts[0].x = x;
        pnts[0].y = yc;
        pnts[1].x = xc;
        pnts[1].y = yc;
        pnts[2].x = xc;
        pnts[2].y = y;

        pnts[3].x = xc + @intCast(i16,wc);
        pnts[3].y = y;
        pnts[4].x = xc + @intCast(i16,wc);
        pnts[4].y = yc;
        pnts[5].x = x + @intCast(i16,w);
        pnts[5].y = yc;

        pnts[6].x = x + @intCast(i16,w);
        pnts[6].y = yc + hc;
        pnts[7].x = xc + wc;
        pnts[7].y = yc + hc;
        pnts[8].x = xc + wc;
        pnts[8].y = y + @intCast(i16,h);

        pnts[9].x = xc;
        pnts[9].y = y + @intCast(i16,h);
        pnts[10].x = xc;
        pnts[10].y = yc + hc;
        pnts[11].x = x;
        pnts[11].y = yc + hc;

        _ = x11.XFillPolygon(surf.dpy, surf.drawable, surf.gc, &pnts[0], 12, x11.Convex, x11.CoordModeOrigin);
        _ = x11.XFillArc(surf.dpy, surf.drawable, surf.gc, xc + wc - r, y, r * 2, r * 2, 0 * 64, 90 * 64);
        _ = x11.XFillArc(surf.dpy, surf.drawable, surf.gc, x, y, r * 2, r * 2, 90 * 64, 90 * 64);
        _ = x11.XFillArc(surf.dpy, surf.drawable, surf.gc, x, yc + hc - r, r * 2, 2 * r, 180 * 64, 90 * 64);
        _ = x11.XFillArc(surf.dpy, surf.drawable, surf.gc, xc + wc - r, yc + hc - r, r * 2, 2 * r, -90 * 64, 90 * 64);
    }
}

fn nk_xsurf_fill_triangle(surf: *XSurface, x0: i16, y0: i16, x1: i16, y1: i16, x2: i16, y2: i16, col: nk.Color) void {
    var pnts: [3]x11.XPoint = undefined;
    pnts[0].x = x0;
    pnts[0].y = y0;
    pnts[1].x = x1;
    pnts[1].y = y1;
    pnts[2].x = x2;
    pnts[2].y = y2;

    const c = nk_color_from_byte(col);

    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _ = x11.XFillPolygon(surf.dpy, surf.drawable, surf.gc, &pnts[0], 3, x11.Convex, x11.CoordModeOrigin);
}

fn nk_xsurf_stroke_triangle(surf: *XSurface, x0: i16, y0: i16, x1: i16, y1: i16, x2: i16, y2: i16, line_thickness: u16, col: nk.Color) void {
    const c = nk_color_from_byte(col);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, x11.JoinMiter);
    _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, x0, y0, x1, y1);
    _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, x1, y1, x2, y2);
    _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, x2, y2, x0, y0);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
}

fn nk_xsurf_fill_polygon(surf: *XSurface, pnts: []nk.Vec2, col: nk.Color) !void {
    var i: usize = 0;
    const MAX_POINTS = 128;
    var xpnts: [MAX_POINTS]XPoint = undefined;
    const c = nk_color_from_byte(col);

    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    while (i < pnts.len and i < MAX_POINTS) : (i += 1) {
        xpnts[i].x = pnts[i].x;
        xpnts[i].y = pnts[i].y;
    }
    _ = x11.XFillPolygon(surf.dpy, surf.drawable, surf.gc, xpnts, count, c11.Convex, x11.CoordModeOrigin);
}

fn nk_xsurf_stroke_polygon(surf: *XSurface, pnts: []nk.Vec2i, line_thickness: u16, col: nk.Color) void {
    var i: usize = 0;
    const c = nk_color_from_byte(col);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, x11.JoinMiter);
    i = 1;
    const count = pnts.len;
    while (i < pnts.len) : (i += 1)
        _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, pnts[i - 1].x, pnts[i - 1].y, pnts[i].x, pnts[i].y);
    _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, pnts[count - 1].x, pnts[count - 1].y, pnts[0].x, pnts[0].y);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
}

fn nk_xsurf_stroke_polyline(surf: *XSurface, pnts: []nk.Vec2, line_thickness: u16, col: nk.Color) void {
    var i: usize = 0;
    const c = nk_color_from_byte(col);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, x11.JoinMiter);
    _=x11.XSetForeground(surf.dpy, surf.gc, c);
    i = 0;
    while (i < pnts.len - 1) : (i += 1)
        _ = x11.XDrawLine(surf.dpy, surf.drawable, surf.gc, pnts[i].x, pnts[i].y, pnts[i + 1].x, pnts[i + 1].y);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
}

fn nk_xsurf_fill_circle(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, col: nk.Color) void {
    const c = nk_color_from_byte(col);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _=x11.XFillArc(surf.dpy, surf.drawable, surf.gc, x, y, w, h, 0, 360 * 64);
}

fn nk_xsurf_stroke_circle(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, line_thickness: u16, col: nk.Color) void {
    const c = nk_color_from_byte(col);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, x11.JoinMiter);
    _ = x11.XSetForeground(surf.dpy, surf.gc, c);
    _ = x11.XDrawArc(surf.dpy, surf.drawable, surf.gc, x, y, w, h, 0, 360 * 64);
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
}

fn nk_xsurf_stroke_curve(surf: *XSurface, p1: nk.Vect2i, p2: nk.Vect2i, p3: nk.Vect2i, p4: nk.Vect2i, num_segments: u16, line_thickness: u16, col: nk.Color) void {
    var i_step: usize;
    var t_step: f32;
    var last: nk.Vect2i = p1;

    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, line_thickness, x11.LineSolid, x11.CapButt, JoinMiter);
    num_segments = std.math.max(num_segments, 1);
    t_step = 1.0 / @intToFloat(f32, num_segments);

    i_step = 1;
    while (i_step < num_segments) : (i_step += 1) {
        var t: f32 = t_step * @intToFloat(f32, i_step);
        var u: f32 = 1.0 - t;
        var w1: f32 = u * u * u;
        var w2: f32 = 3 * u * u * t;
        var w3: f32 = 3 * u * t * t;
        var w4: f32 = t * t * t;
        var x: f32 = w1 * p1.x + w2 * p2.x + w3 * p3.x + w4 * p4.x;
        var y: f32 = w1 * p1.y + w2 * p2.y + w3 * p3.y + w4 * p4.y;
        nk_xsurf_stroke_line(surf, last.x, last.y, x, y, line_thickness, col);
        last.x = x;
        last.y = y;
    }
    _ = x11.XSetLineAttributes(surf.dpy, surf.gc, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
}

fn nk_xsurf_draw_text(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, text: []const u8, font: *XFont, cbg: nk.Color, cfg: nk.Color) void {
    var tx: i32;
    var ty: i32;

    const bg = nk_color_from_byte(&cbg.r);
    const fg = nk_color_from_byte(&cfg.r);

    _ = x11.XSetForeground(surf.dpy, surf.gc, bg);
    _ = x11.XFillRectangle(surf.dpy, surf.drawable, surf.gc, x, y, w, h);
    if (!text || !font || !len) return;

    tx = x;
    ty = y + font.ascent;
    _ = x11.XSetForeground(surf.dpy, surf.gc, fg);

    if (font.set) {
        _ = x11.XmbDrawString(surf.dpy, surf.drawable, font.set, surf.gc, tx, ty, text.ptr, text.len);
    } else {
        _ = x11.XDrawString(surf.dpy, surf.drawable, surf.gc, tx, ty, text.ptr, text.len);
    }
}

const Driver = struct {
    clipboard_data: [*]u8,
    clipboard_len: u32,
    clipboard_target: *nk.TextEdit,

    xa_clipboard: x11.Atom,
    xa_targets: x11.Atom,
    xa_text: x11.Atom,
    xa_utf8_string: x11.Atom,

    // associated surface (displayed window)
    surf: *XSurface,

    cursor: x11.Cursor,

    dpy: *x11.Display,
    root: x11.Window, // associated display windows

    last_button_click: u32,

    const Self = @This();

    fn nk_xsurf_image_free(self: *Self, image: *nk.Image) void {
        XSurface * surf = self.surf;
        XImageWithAlpha * aimage = image.handle.ptr;
        if (!aimage) return;
        x11.XDestroyImage(aimage.ximage);
        x11.XFreePixmap(surf.dpy, aimage.clipMask);
        x11.XFreeGC(surf.dpy, aimage.clipMaskGC);
        libc.free(aimage);
    }

    fn nk_xlib_init(self: *Self, xfont: *XFont, dpy: *Display, screen: i32, root: Window, w: u32, h: u32) *nk.Context {
        const font: *nk_user_font = &xfont.handle;
        font.userdata = nk_handle_ptr(xfont);
        font.height = @intToFloat(f32, xfont.height);
        font.width = nk_xfont_get_text_width;
        self.dpy = dpy;
        self.root = root;

        if (!setlocale(LC_ALL, "")) return 0;
        if (!XSupportsLocale()) return 0;
        if (!XSetLocaleModifiers("@im=none")) return 0;

        self.xa_clipboard = XInternAtom(dpy, "CLIPBOARD", False);
        self.xa_targets = XInternAtom(dpy, "TARGETS", False);
        self.xa_text = XInternAtom(dpy, "TEXT", False);
        self.xa_utf8_string = XInternAtom(dpy, "UTF8_STRING", False);

        // create invisible cursor
        {
            var dummy: XColor;
            var data: [1]u8 = []u8{0};
            const blank: Pixmap = XCreateBitmapFromData(dpy, root, data, 1, 1);
            if (blank == None) return 0;
            self.cursor = XCreatePixmapCursor(dpy, blank, blank, &dummy, &dummy, 0, 0);
            XFreePixmap(dpy, blank);
        }

        self.surf = nk_xsurf_create(screen, w, h);
        nk_init_default(&xlib.ctx, font);
        return &self.ctx;
    }

    fn nk_xlib_paste(self: *Self, handle: nk_handle, edit: *nk_text_edit) void {
        // NK_UNUSED(handle);
        // Paste in X is asynchronous, so can not use a temporary text edit
        std.debug.assert(edit != &self.ctx.text_edit); // "Paste not supported for temporary editors");
        xlib.clipboard_target = edit;
        // Request the contents of the primary buffer */
        XConvertSelection(self.dpy, XA_PRIMARY, XA_STRING, XA_PRIMARY, self.root, CurrentTime);
    }

    fn nk_xlib_copy(self: *Self, handle: nk_handle, str: []u8, len: u32) void {
        // NK_UNUSED(handle);
        x11.free(xlib.clipboard_data);
        self.clipboard_len = 0;
        self.clipboard_data = x11.malloc(@as(usize, len));
        if (self.clipboard_data) {
            memcpy(xlib.clipboard_data, str, @as(usize, len));
            self.clipboard_len = len;
            x11.XSetSelectionOwner(self.dpy, XA_PRIMARY, self.root, CurrentTime);
            x11.XSetSelectionOwner(self.dpy, self.xa_clipboard, self.root, CurrentTime);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    // event handling

    fn handleAllCurrentEvents(self: *Self, ctx:*nk.Context, surf: *XSurface) anyerror!bool {
          
        var evt:x11.XEvent = undefined;
        var started = timeStamp();
        nk.input.begin(ctx);
        defer nk.input.end(ctx);

        while (x11.XPending(surf.dpy) > 0) {
            _ = x11.XNextEvent(surf.dpy, &evt);
            if (evt.type == x11.ClientMessage) return true; // end ??
            if (x11.XFilterEvent(&evt, surf.win) != 0) continue;
            _= self.nk_xlib_handle_event(ctx, surf.dpy, surf.screen, surf.win, &evt);
        }
        
        return false;
    }

    fn nk_xlib_handle_event(self: *Self, ctx: *nk.Context , dpy: *x11.Display, screen: i32, win: x11.Window, evt: *x11.XEvent) u32 {
        
        // optional grabbing behavior
        if (ctx.input.mouse.grab != 0) {
            _ = x11.XDefineCursor(dpy, win, self.cursor);
            ctx.input.mouse.grab = 0;
        } else if (ctx.input.mouse.ungrab != 0) {
            _ = x11.XWarpPointer(dpy, x11.None, self.root, 0, 0, 0, 0, @as(c_int, ctx.input.mouse.prev.x), @as(c_int, ctx.input.mouse.prev.y));
            _ = x11.XUndefineCursor(dpy, self.root);
            ctx.input.mouse.ungrab = 0;
        }

        if (evt.type == x11.KeyPress or evt.type == x11.KeyRelease) {
            // Key handler
            // var ret;
            const down = (evt.type == KeyPress);
            const code: *KeySym = x11.XGetKeyboardMapping(xlib.surf.dpy, @as(KeyCode, evt.xkey.keycode), 1, &ret);
            if (code.* == XK_Shift_L or code.* == XK_Shift_R) {
                nk.input.key(ctx, NK_KEY_SHIFT, down);
            } else if (code.* == XK_Control_L or code.* == XK_Control_R) nk.input.key(ctx, NK_KEY_CTRL, down) else if (code.* == XK_Delete) nk.input.key(ctx, NK_KEY_DEL, down) else if (code.* == XK_Return) nk.input.key(ctx, NK_KEY_ENTER, down) else if (code.* == XK_Tab) nk.input.key(ctx, NK_KEY_TAB, down) else if (code.* == XK_Left) nk.input.key(ctx, NK_KEY_LEFT, down) else if (code.* == XK_Right) nk.input.key(ctx, NK_KEY_RIGHT, down) else if (code.* == XK_Up) nk.input.key(ctx, NK_KEY_UP, down) else if (code.* == XK_Down) nk.input.key(ctx, NK_KEY_DOWN, down) else if (code.* == XK_BackSpace) nk.input.key(ctx, NK_KEY_BACKSPACE, down) else if (code.* == XK_Escape) nk.input.key(ctx, NK_KEY_TEXT_RESET_MODE, down) else if (code.* == XK_Page_Up) nk.input.key(ctx, NK_KEY_SCROLL_UP, down) else if (code.* == XK_Page_Down) nk.input.key(ctx, NK_KEY_SCROLL_DOWN, down) else if (code.* == XK_Home) {
                nk.input.key(ctx, NK_KEY_TEXT_START, down);
                nk.input.key(ctx, NK_KEY_SCROLL_START, down);
            } else if (code.* == XK_End) {
                nk.input.key(ctx, NK_KEY_TEXT_END, down);
                nk.input.key(ctx, NK_KEY_SCROLL_END, down);
            } else if (code.* == 'c' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_COPY, down)
            else if (code.* == 'v' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_PASTE, down)
            else if (code.* == 'x' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_CUT, down)
            else if (code.* == 'z' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_TEXT_UNDO, down)
            else if (code.* == 'r' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_TEXT_REDO, down)
            else if (code.* == XK_Left and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_TEXT_WORD_LEFT, down)
            else if (code.* == XK_Right and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_TEXT_WORD_RIGHT, down)
            else if (code.* == 'b' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_TEXT_LINE_START, down)
            else if (code.* == 'e' and (evt.xkey.state & ControlMask) != 0)
                nk.input.key(ctx, NK_KEY_TEXT_LINE_END, down)
            else {
                if (code.* == 'i') {
                    nk.input.key(ctx, NK_KEY_TEXT_INSERT_MODE, down);
                } else if (code.* == 'r') {
                    nk.input.key(ctx, NK_KEY_TEXT_REPLACE_MODE, down);
                }

                if (down != 0) {
                    var buf: [32]u8 = undefined;
                    var keysym: KeySym = 0;
                    if (x11.XLookupString(@ptrCast(*XKeyEvent, evt), buf, 32, &keysym, null) != NoSymbol)
                        nk.input.glyph(ctx, buf);
                }
            }

            x11.XFree(code);
            return 1;
        } else if (evt.type == ButtonPress or evt.type == ButtonRelease) {
            // Button handler
            const down = (evt.type == ButtonPress);
            const x = evt.xbutton.x;
            const y = evt.xbutton.y;
            if (evt.xbutton.button == Button1) {
                if (down) { // Double-Click Button handler
                    const dt = nk_timestamp() - xlib.last_button_click;
                    if (dt > NK_X11_DOUBLE_CLICK_LO and dt < NK_X11_DOUBLE_CLICK_HI)
                        nk.input.button(ctx, NK_BUTTON_DOUBLE, x, y, nk_true);
                    xlib.last_button_click = nk_timestamp();
                } else nk.input.button(ctx, NK_BUTTON_DOUBLE, x, y, nk_false);
                nk.input.button(ctx, NK_BUTTON_LEFT, x, y, down);
            } else if (evt.xbutton.button == Button2)
                nk.input.button(ctx, NK_BUTTON_MIDDLE, x, y, down)
            else if (evt.xbutton.button == Button3)
                nk.input.button(ctx, NK_BUTTON_RIGHT, x, y, down)
            else if (evt.xbutton.button == Button4)
                nk.input.scroll(ctx, nk.vec2(0, 1.0))
            else if (evt.xbutton.button == Button5)
                nk.input.scroll(ctx, nk.vec2(0, -1.0))
            else
                return 0;

            return 1;
        } else if (evt.type == MotionNotify) {
            // Mouse motion handler
            const x = evt.xmotion.x;
            const y = evt.xmotion.y;
            nk.input.motion(ctx, x, y);
            if (ctx.input.mouse.grabbed) {
                ctx.input.mouse.pos.x = ctx.input.mouse.prev.x;
                ctx.input.mouse.pos.y = ctx.input.mouse.prev.y;
                _ = x11.XWarpPointer(xlib.dpy, None, xlib.surf.root, 0, 0, 0, 0, ctx.input.mouse.pos.x, ctx.input.mouse.pos.y);
            }
            return 1;
        } else if (evt.type == Expose or evt.type == ConfigureNotify) {
            // Window resize handler
            var attr: XWindowAttributes = undefined;
            _ = x11.XGetWindowAttributes(dpy, win, &attr);

            const width = attr.width;
            const height = attr.height;

            nk_xsurf_resize(xlib.surf, width, height);
            return 1;
        } else if (evt.type == KeymapNotify) {
            _ = x11.XRefreshKeyboardMapping(&evt.xmapping);
            return 1;
        } else if (evt.type == SelectionClear) {
            xlib.free(self.clipboard_data);
            self.clipboard_data = NULL;
            self.clipboard_len = 0;
            return 1;
        } else if (evt.type == SelectionRequest) {
            var reply: XEvent = undefined;
            reply.xselection.type = SelectionNotify;
            reply.xselection.requestor = evt.xselectionrequest.requestor;
            reply.xselection.selection = evt.xselectionrequest.selection;
            reply.xselection.target = evt.xselectionrequest.target;
            reply.xselection.property = None; // Default refuse
            reply.xselection.time = evt.xselectionrequest.time;

            if (reply.xselection.target == xlib.xa_targets) {
                var target_list: [4]Atom = undefined;
                target_list[0] = xlib.xa_targets;
                target_list[1] = xlib.xa_text;
                target_list[2] = xlib.xa_utf8_string;
                target_list[3] = XA_STRING;

                reply.xselection.property = evt.xselectionrequest.property;
                _=x11.XChangeProperty(evt.xselection.display, evt.xselectionrequest.requestor, reply.xselection.property, XA_ATOM, 32, PropModeReplace, &target_list, // (unsigned char*)
                    4);
            } else if (xlib.clipboard_data != 0 and (reply.xselection.target == xlib.xa_text or
                reply.xselection.target == xlib.xa_utf8_string or reply.xselection.target == XA_STRING))
            {
                reply.xselection.property = evt.xselectionrequest.property;
                _=x11.XChangeProperty(evt.xselection.display, evt.xselectionrequest.requestor, reply.xselection.property, reply.xselection.target, 8, PropModeReplace, xlib.clipboard_data // (unsigned char*)

                , xlib.clipboard_len);
            }
            _= x11.XSendEvent(evt.xselection.display, evt.xselectionrequest.requestor, true, 0, &reply);
            _=x11.XFlush(evt.xselection.display);
            return 1;
        } else if (evt.type == SelectionNotify and xlib.clipboard_target) {
            if ((evt.xselection.target != XA_STRING) and
                (evt.xselection.target != xlib.xa_utf8_string) and
                (evt.xselection.target != xlib.xa_text))
                return 1;

            {
                var actual_type: Atom = undefined;
                var actual_format: u32 = undefined;
                var pos: u64 = 0;
                var len: usize = 0;
                var remain = 1; // for do while ...
                var data: [*c]const u8 = "";
                while (remain != 0) {
                    _= x11.XGetWindowProperty(dpy, win, XA_PRIMARY, @as(c_int, pos), 1024, False, x11.AnyPropertyType, &actual_type, &actual_format, &len, &remain, &data);
                    if (len != 0 and data != 0)
                        nk.textedit.text(xlib.clipboard_target, data, len);
                    if (data != 0) x11.XFree(data);
                    pos += (len * @as(u64, actual_format)) / 32;
                }
                return 1;
            }
            return 0;
        }
    }

    //////////////////////////////////////////////////////////////////////////////
    // rendering

    fn render(self: *Self, ctx: *nk.Context, surf: *XSurface) anyerror!void {
        // struct nk_color clear
        const clear = nk.rgb(0, 0, 0);

        nk_xsurf_clear(surf, clear);

        if (ctx.*.memory.size > 0) {
            var itCmd = nk.iterator(ctx);

            while (itCmd.next()) |cmd| {
                switch (cmd) {
                    .scissor => {
                        const s = cmd.scissor;
                        nk_xsurf_scissor(surf, s.x, s.y, s.w, s.h);
                    },
                    .line => {
                        const l = cmd.line;
                        nk_xsurf_stroke_line(surf, l.begin.x, l.begin.y, l.end.x, l.end.y, l.line_thickness, l.color);
                    },
                    .rect => {
                        const r = cmd.rect;
                        nk_xsurf_stroke_rect(surf, r.x, r.y, std.math.max(r.w - r.line_thickness, 0), std.math.max(r.h - r.line_thickness, 0), r.rounding, r.line_thickness, r.color);
                    },
                    .rect_filled => {
                        const r = cmd.rect_filled;
                        nk_xsurf_fill_rect(surf, r.x, r.y, r.w, r.h, r.rounding, r.color);
                    },
                    .circle => {
                        const c = cmd.circle;
                        nk_xsurf_stroke_circle(surf, c.x, c.y, c.w, c.h, c.line_thickness, c.color);
                    },
                    .circle_filled => {
                        const c = cmd.circle_filled;
                        nk_xsurf_fill_circle(surf, c.x, c.y, c.w, c.h, c.color);
                    },
                    .triangle => {
                        const t = cmd.triangle;
                        nk_xsurf_stroke_triangle(surf, t.a.x, t.a.y, t.b.x, t.b.y, t.c.x, t.c.y, t.line_thickness, t.color);
                    },
                    .triangle_filled => {
                        const t = cmd.triangle_filled;
                        nk_xsurf_fill_triangle(surf, t.a.x, t.a.y, t.b.x, t.b.y, t.c.x, t.c.y, t.color);
                    },
                    .polygon => {
                        const p = cmd.polygon;
                        nk_xsurf_stroke_polygon(surf, p.points, p.point_count, p.line_thickness, p.color);
                    },
                    .polygon_filled => {
                        const p = cmd.polygon_filled;
                        nk_xsurf_fill_polygon(surf, p.points, p.point_count, p.color);
                    },

                    .polyline => {
                        const p = cmd.polyline;
                        nk_xsurf_stroke_polyline(surf, p.points, p.point_count, p.line_thickness, p.color);
                    },
                    .text => {
                        const t = cmd.text;
                        nk_xsurf_draw_text(surf, t.x, t.y, t.w, t.h, t.string, t.length, @ptrCast(*XFont, t.font.userdata.ptr), t.background, t.foreground);
                    },
                    .curve => {
                        const q = cmd.curve;
                        nk_xsurf_stroke_curve(surf, q.begin, q.ctrl[0], q.ctrl[1], q.end, 22, q.line_thickness, q.color);
                    },
                    .image => {
                        const i = cmd.image;
                        nk_xsurf_draw_image(surf, i.x, i.y, i.w, i.h, i.img, i.col);
                    },
                    .rect_multi_color => {},
                    .custom => {},
                    .arc_filled => {},
                    .arc => {},
                    // case NK_COMMAND_RECT_MULTI_COLOR:
                    // case NK_COMMAND_ARC:
                    // case NK_COMMAND_ARC_FILLED:
                    //case NK_COMMAND_CUSTOM:
                    // default: break;
                }
            }
            nk_clear(ctx);
            nk_xsurf_blit(screen, surf, surf.w, surf.h);
        }
    }

    fn nk_xlib_shutdown() void {
        nk_xsurf_del(xlib.surf);

        nk_free(&xlib.ctx);

        XFreeCursor(xlib.dpy, xlib.cursor);

        memset(&xlib, 0, sizeof(xlib));
    }
};
