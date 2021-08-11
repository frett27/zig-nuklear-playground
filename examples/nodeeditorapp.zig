const std = @import("std");
const nk = @import("zig-nuklear");

const nkstyle = @import("nk-style.zig");

const nksdl = @import("backend-sdl.zig");

const nodeeditor = @import("node-editor.zig");

var test_default_atlas: nk.FontAtlas = undefined;
var test_default_font: ?*nk.UserFont = null;

fn testDefaultFont(allocator: *std.mem.Allocator) !*nk.UserFont {
    if (test_default_font) |res|
        return res;

    test_default_atlas = nk.atlas.init(allocator);
    test_default_font = &(try nk.atlas.addDefault(&test_default_atlas, 13, null)).handle;
    _ = try nk.atlas.bake(&test_default_atlas, .NK_FONT_ATLAS_RGBA32);
    nk.atlas.end(&test_default_atlas, .{ .id = 0 }, null);
    const f = test_default_font.?;

    return test_default_font.?;
}

pub fn main() !void {

    const globalAllocator = std.heap.c_allocator;

    var font: *nk.UserFont = testDefaultFont(globalAllocator) catch @panic("cannot allocate font");
    
    // memory pool for fixed allocator used by nk
    const MAXMEMORY = 2_000_000;
    var memory = try globalAllocator.alloc(u8, MAXMEMORY);

    // faced lots or segfaults using the zig dynamic allocator
    // during free .. , using this command below :
    // var ctx = nk.init(globalAllocator, font);
    // switch to initFixed seems more reliable
    var ctx = nk.initFixed(memory, font);

    // init sdl backend
    try nksdl.initSDL();

    // create the main window
    var win: *nksdl.SDL_Window = try nksdl.createWindow();

    var nkSDL = try nksdl.Driver.init(globalAllocator, win);

    nkstyle.setStyle(&ctx, nkstyle.Theme.THEME_BLUE);


    var running = true;

    while (running) {

            running = nkSDL.handleAllCurrentEvents(win, &ctx);

            // Draw
            _= try nodeeditor.nodeEditorMain(&ctx);

            try nkSDL.render(&ctx, win, 0);
    }

}