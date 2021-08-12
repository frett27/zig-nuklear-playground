const nk = @import("zig-nuklear");
const std = @import("std");

pub usingnamespace @cImport({
    @cInclude("X11/Xlib.h");
});

pub fn initX11() !void {}

//////////////////////////////////////////////////////////
// X11 functions

const XFont = struct {
    ascent: i32,
    descent: i32,
    height: i32,
    set: XFontSet,
    xfont: *XFontStruct,
    handle: nk.Font,
};

const XSurface = struct {
    gc: GC,
    dpy: *Display,
    screen: i32,
    root: Window,
    drawable: Drawable,
    w: u32,
    h: u32,
};
const XImageWithAlpha = struct {
    ximage: *XImage,
    clipMaskGC: GC,
    clipMask: Pixmap,
};
const XLib = struct {
    clipboard_data: [*]u8,
    clipboard_len: u32,
    clipboard_target: *nk.text.Edit,

    xa_clipboard: Atom,
    xa_targets: Atom,
    xa_text: Atom,
    xa_utf8_string: Atom,

    ctx: *nk.Context,
    surf: *XSurface,
    cursor: Cursor,
    dpy: *Display,
    root: Window,
    last_button_click: u32,
};

fn nk_xsurf_draw_image(surf: *XSurface, x: i16, y: i16, w: u16, h: u16, img: nk.Image, col: nk.Color) void {
    XImageWithAlpha * aimage = img.handle.ptr;
    if (aimage) {
        if (aimage.clipMask) {
            XSetClipMask(surf.dpy, surf.gc, aimage.clipMask);
            XSetClipOrigin(surf.dpy, surf.gc, x, y);
        }
        XPutImage(surf.dpy, surf.drawable, surf.gc, aimage.ximage, 0, 0, x, y, w, h);
        XSetClipMask(surf.dpy, surf.gc, None);
    }
}

fn nk_xsurf_image_free(image: *nk.Image) void {
    XSurface * surf = xlib.surf;
    XImageWithAlpha * aimage = image.handle.ptr;
    if (!aimage) return;
    XDestroyImage(aimage.ximage);
    XFreePixmap(surf.dpy, aimage.clipMask);
    XFreeGC(surf.dpy, aimage.clipMaskGC);
    free(aimage);
}

fn nk_xsurf_clear(surf: *XSurface, color: nk.Color) void {
    XSetForeground(surf.dpy, surf.gc, color);
    XFillRectangle(surf.dpy, surf.drawable, surf.gc, 0, 0, surf.w, surf.h);
}

fn nk_xsurf_blit(target: Drawable, surf: *XSurface, w: u32, h: u32) void {
    XCopyArea(surf.dpy, surf.drawable, target, surf.gc, 0, 0, w, h, 0, 0);
}

fn nk_xsurf_del(surf: *XSurface) void {
    XFreePixmap(surf.dpy, surf.drawable);
    XFreeGC(surf.dpy, surf.gc);
    free(surf);
}

fn nk_xfont_create(dpy: *Display, name: [*c]const u8) *XFont {
    var n: i32 = 0;
    var def: [*]u8 = undefined;
    var missing: *[*]u8 = undefined;

    XFont * font = @ptrCast(*XFont, calloc(1, sizeof(XFont)));

    font.set = XCreateFontSet(dpy, name, &missing, &n, &def);
    if (missing) {
        while (n > 0) : (n -= 1)
            fprintf(stderr, "missing fontset: %s\n", missing[n]);
        XFreeStringList(missing);
    }
    if (font.set) {
        XFontStruct ** xfonts;
        char ** font_names;
        XExtentsOfFontSet(font.set);
        n = XFontsOfFontSet(font.set, &xfonts, &font_names);
        while (n > 0) : (n -= 1) {
            font.ascent = std.math.max(font.ascent, (*xfonts).ascent);
            font.descent = std.math.max(font.descent, (*xfonts).descent);
            xfonts += 1;
        }
    } else {
        font.xfont = XLoadQueryFont(dpy, name);

        if (font.xfont == 0) {
            font.xfont = XLoadQueryFont(dpy, "fixed");
            if (font.xfont == 0) {
                free(font);
                return 0;
            }
        }
        font.ascent = font.xfont.ascent;
        font.descent = font.xfont.descent;
    }
    font.height = font.ascent + font.descent;
    return font;
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

fn nk_xlib_init(xfont: *XFont, dpy: *Display, screen: i32, root: Window, w: u32, h: u32) *nk.Context {
    const font: *nk_user_font = &xfont.handle;
    font.userdata = nk_handle_ptr(xfont);
    font.height = @intToFloat(f32, xfont.height);
    font.width = nk_xfont_get_text_width;
    xlib.dpy = dpy;
    xlib.root = root;

    if (!setlocale(LC_ALL, "")) return 0;
    if (!XSupportsLocale()) return 0;
    if (!XSetLocaleModifiers("@im=none")) return 0;

    xlib.xa_clipboard = XInternAtom(dpy, "CLIPBOARD", False);
    xlib.xa_targets = XInternAtom(dpy, "TARGETS", False);
    xlib.xa_text = XInternAtom(dpy, "TEXT", False);
    xlib.xa_utf8_string = XInternAtom(dpy, "UTF8_STRING", False);

    // create invisible cursor
    {
        var dummy: XColor;
        var data: [1]u8 = []u8{0};
        const blank: Pixmap = XCreateBitmapFromData(dpy, root, data, 1, 1);
        if (blank == None) return 0;
        xlib.cursor = XCreatePixmapCursor(dpy, blank, blank, &dummy, &dummy, 0, 0);
        XFreePixmap(dpy, blank);
    }

    xlib.surf = nk_xsurf_create(screen, w, h);
    nk_init_default(&xlib.ctx, font);
    return &xlib.ctx;
}

fn nk_xlib_set_font(xfont: *XFont) void {
    const font: *nk_user_font = &xfont.handle;
    font.userdata = nk_handle_ptr(xfont);
    font.height = @intToFloat(f32, xfont.height);
    font.width = nk_xfont_get_text_width;
    nk_style_set_font(&xlib.ctx, font);
}

fn nk_xlib_push_font(xfont: *XFont) void {
    const font: *nk_user_font = &xfont.handle;
    font.userdata = nk_handle_ptr(xfont);
    font.height = @intToFloat(f32, xfont.height);
    font.width = nk_xfont_get_text_width;
    nk_style_push_font(&xlib.ctx, font);
}

fn nk_xlib_paste(handle: nk_handle, edit: *nk_text_edit) void {
    NK_UNUSED(handle);
    // Paste in X is asynchronous, so can not use a temporary text edit
    std.debug.assert(edit != &xlib.ctx.text_edit); // "Paste not supported for temporary editors");
    xlib.clipboard_target = edit;
    // Request the contents of the primary buffer */
    XConvertSelection(xlib.dpy, XA_PRIMARY, XA_STRING, XA_PRIMARY, xlib.root, CurrentTime);
}

fn nk_xlib_copy(handle: nk_handle, str: []u8, len: u32) void {
    NK_UNUSED(handle);
    free(xlib.clipboard_data);
    xlib.clipboard_len = 0;
    xlib.clipboard_data = malloc(@as(usize, len));
    if (xlib.clipboard_data) {
        memcpy(xlib.clipboard_data, str, @as(usize, len));
        xlib.clipboard_len = len;
        XSetSelectionOwner(xlib.dpy, XA_PRIMARY, xlib.root, CurrentTime);
        XSetSelectionOwner(xlib.dpy, xlib.xa_clipboard, xlib.root, CurrentTime);
    }
}

fn nk_xlib_handle_event(dpy: *Display, screen: i32, win: Window, evt: *XEvent) u32 {
    const ctx = &xlib.ctx;

    // optional grabbing behavior
    if (ctx.input.mouse.grab) {
        XDefineCursor(xlib.dpy, xlib.root, xlib.cursor);
        ctx.input.mouse.grab = 0;
    } else if (ctx.input.mouse.ungrab) {
        XWarpPointer(xlib.dpy, None, xlib.root, 0, 0, 0, 0, @as(c_int, ctx.input.mouse.prev.x), @as(c_int, ctx.input.mouse.prev.y));
        XUndefineCursor(xlib.dpy, xlib.root);
        ctx.input.mouse.ungrab = 0;
    }

    if (evt.type == KeyPress or evt.type == KeyRelease) {
        // Key handler
        var ret;
        const down = (evt.type == KeyPress);
        const code: *KeySym = XGetKeyboardMapping(xlib.surf.dpy, @as(KeyCode, evt.xkey.keycode), 1, &ret);
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

            if (down) {
                var buf: [32]u8 = undefined;
                var keysym: KeySym = 0;
                if (XLookupString(@ptrCast(*XKeyEvent, evt), buf, 32, &keysym, null) != NoSymbol)
                    nk.input.glyph(ctx, buf);
            }
        }

        XFree(code);
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
            XWarpPointer(xlib.dpy, None, xlib.surf.root, 0, 0, 0, 0, ctx.input.mouse.pos.x, ctx.input.mouse.pos.y);
        }
        return 1;
    } else if (evt.type == Expose or evt.type == ConfigureNotify) {
        // Window resize handler
        var attr: XWindowAttributes = undefined;
        XGetWindowAttributes(dpy, win, &attr);

        const width = attr.width;
        const height = attr.height;

        nk_xsurf_resize(xlib.surf, width, height);
        return 1;
    } else if (evt.type == KeymapNotify) {
        XRefreshKeyboardMapping(&evt.xmapping);
        return 1;
    } else if (evt.type == SelectionClear) {
        free(xlib.clipboard_data);
        xlib.clipboard_data = NULL;
        xlib.clipboard_len = 0;
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
            XChangeProperty(evt.xselection.display, evt.xselectionrequest.requestor, reply.xselection.property, XA_ATOM, 32, PropModeReplace, &target_list, // (unsigned char*)
                4);
        } else if (xlib.clipboard_data != 0 and (reply.xselection.target == xlib.xa_text or
            reply.xselection.target == xlib.xa_utf8_string or reply.xselection.target == XA_STRING))
        {
            reply.xselection.property = evt.xselectionrequest.property;
            XChangeProperty(evt.xselection.display, evt.xselectionrequest.requestor, reply.xselection.property, reply.xselection.target, 8, PropModeReplace, xlib.clipboard_data // (unsigned char*)

            , xlib.clipboard_len);
        }
        XSendEvent(evt.xselection.display, evt.xselectionrequest.requestor, true, 0, &reply);
        XFlush(evt.xselection.display);
        return 1;
    } else if (evt.type == SelectionNotify and xlib.clipboard_target) {
        if ((evt.xselection.target != XA_STRING) and
            (evt.xselection.target != xlib.xa_utf8_string) and
            (evt.xselection.target != xlib.xa_text))
            return 1;

        {
            var actual_type: Atom = undefined;
            var actual_format: u32;
            var pos: u64 = 0;
            var len: usize = 0;
            var remain = 1; // for do while ...
            var data: [*c]const u8 = "";
            while (remain != 0) {
                XGetWindowProperty(dpy, win, XA_PRIMARY, @as(c_int, pos), 1024, False, AnyPropertyType, &actual_type, &actual_format, &len, &remain, &data);
                if (len != 0 and data != 0)
                    nk_textedit_text(xlib.clipboard_target, data, len);
                if (data != 0) XFree(data);
                pos += (len * @as(u64, actual_format)) / 32;
            }
            return 1;
        }
        return 0;
    }
}

fn nk_xlib_shutdown() void {
    nk_xsurf_del(xlib.surf);

    nk_free(&xlib.ctx);
    XFreeCursor(xlib.dpy, xlib.cursor);
    memset(&xlib, 0, sizeof(xlib));
}

fn nk_xlib_render(ctx: *nk.Context, screen: Drawable) void {
    // struct nk_color clear
    const surf: *XSurface = xlib.surf;

    nk_xsurf_clear(xlib.surf, nk_color_from_byte(&clear.r));

    if (ctx.*.memory.size > 0) {
        var itCmd = nk.iterator(ctx);

        while (itCmd.next()) |cmd| {
            switch (cmd) {

                // case NK_COMMAND_NOP: break;
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
                _ => {},
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
