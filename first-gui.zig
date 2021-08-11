const std = @import("std");
const nk = @import("zig-nuklear");

const nksdl = @import("backends/backend-sdl.zig");
const nkstyle = @import("nk-style.zig");

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


    /////////////////////////////////////////
    // Application part 
    //
    // gui state

    var running = true; // for main loop

    var b = true;
    var b2 = false;
    var selectedcb: usize = 0;

    var sliderval: c_int = 0;
    var cursorprogress: usize = 0;

    var treestate: nk.CollapseStates = undefined;

    var slidefloat: f32 = 0.0;

    var checkstate = true;

    var img = try nkSDL.loadImage("zig.png");

    var bounds: nk.Rect = nk.rest.nkGetNullRect();

    var show_menu = false;
    var menu_progress: usize = 0;
    var menu_slider: c_int = 0;

    while (running) {
        running = nkSDL.handleAllCurrentEvents(win, &ctx);

        // // GUI
        const WindowID = "Demo";
        if (nk.window.beginTitled(&ctx, WindowID, nk.rect(50, 50, 400, 400), .{ .title = "Hello Window SDL Rendering", .scalable = true, .border = true, .moveable = true })) |nkwin| {

            // a menubar
            nk.menubar.begin(&ctx);
            {
                defer nk.menubar.end(&ctx);

                nk.layout.rowBegin(&ctx, .NK_STATIC, 25, 5);

                nk.layout.rowPush(&ctx, 45);
                // show contextual menu

                if (nk.menu.beginLabel(&ctx, "Menu", nk.text.Align.mid_left, nk.vec2(100, 300))) {
                    defer nk.menu.end(&ctx);

                    nk.layout.rowDynamic(&ctx, 25, 1);
                    _ = nk.checkbox.label(&ctx, "Menu", &show_menu);
                    _ = nk.bar.progress(&ctx, &menu_progress, 100, true);
                    _ = nk.slider.int(&ctx, 0, &menu_slider, 16, 1);
                    if (nk.contextual.itemLabel(&ctx, "About", nk.text.Align.mid_left)) {}
                }
            }

            // an image
            nk.layout.rowStatic(&ctx, 100, 500, 1);
            nk.text.image(&ctx, img);

            // a button
            nk.layout.rowStatic(&ctx, 30, 400, 1);
            if (nk.button.label(&ctx, "button")) {
                std.debug.print("button pressed\n", .{});
            }

            _ = nk.button.label(&ctx, "Hello world");

            // a contextual
            nk.layout.rowStatic(&ctx, 30, 160, 1);
            var contextualbounds = nk.widget.bounds(&ctx);
            _ = nk.button.label(&ctx, "Right click me for menu");
            if (nk.contextual.begin(&ctx, 0, nk.vec2(100, 300), contextualbounds)) {
                defer nk.contextual.end(&ctx);

                nk.layout.rowDynamic(&ctx, 25, 1);
                if (nk.contextual.itemLabel(&ctx, "The Contextual", nk.text.Align.mid_left)) {
                    std.debug.print("Contextual clicked\n", .{});
                }
            }

            // some radio buttons
            _ = nk.radio.label(&ctx, "radio label", &b);
            if (nk.radio.label(&ctx, "radio label 2", &b2)) {
                std.debug.print("radio pressed\n", .{});
            }

            // a combo
            selectedcb = nk.combo.string(&ctx, "one\x00two\x00three\x00", selectedcb, 3, 15, nk.vec2(300, 100));

            // a slider
            _ = nk.slider.int(&ctx, 0, &sliderval, 255, 1);

            // a progress bar
            _ = nk.bar.progress(&ctx, &cursorprogress, 100, true);

            // small tree
            if (nk.tree.push(&ctx, opaque {}, .NK_TREE_TAB, "tree", .NK_MINIMIZED)) {
                defer nk.tree.pop(&ctx);

                if (nk.tree.push(&ctx, opaque {}, .NK_TREE_TAB, "tree 2", .NK_MINIMIZED)) {
                    defer nk.tree.pop(&ctx);
                }
            }

            // add slide float
            slidefloat = nk.slide.float(&ctx, 0.0, slidefloat, 100.0, 1.0);

            // add label
            nk.text.label(&ctx, "text", nk.text.Align.mid_left);

            // add checkbox
            checkstate = nk.check.label(&ctx, "check", checkstate);

            // add list, using view and allocate some specific
            nk.layout.rowStatic(&ctx, 200, 200, 1);
            if (nk.group.begin(&ctx, opaque {}, .{})) {
                defer nk.group.end(&ctx);
                nk.layout.rowDynamic(&ctx, 200, 1);
                if (nk.list.begin(&ctx, opaque {}, 200, 10, .{})) |l| {
                    defer nk.list.end(l);
                    nk.layout.rowStatic(&ctx, 30, 100, 1);
                    _ = nk.button.label(&ctx, "option 1");
                    _ = nk.button.label(&ctx, "option 2");
                    _ = nk.button.label(&ctx, "option 3");
                }
            }

            const values = [_]f32{ 26.0, 13.0, 30.0, 15.0, 25.0, 10.0, 20.0, 40.0, 12.0, 8.0, 22.0, 28.0 };
            nk.layout.rowDynamic(&ctx, 150, 1);
            bounds = nk.widget.bounds(&ctx);
            if (nk.chart.begin(&ctx, nk.ChartType.NK_CHART_COLUMN, values.len, 0, 50)) {
                var it: u32 = 0;
                defer nk.chart.end(&ctx);
                while (it < values.len) {
                    _ = nk.chart.push(&ctx, values[it]);
                    it += 1;
                }
            }

            nk.layout.rowDynamic(&ctx, 150, 1);
            if (nk.chart.begin(&ctx, nk.ChartType.NK_CHART_LINES, values.len, -0.0, 50.0)) {
                var it: u32 = 0;
                defer nk.chart.end(&ctx);
                while (it < values.len) {
                    _ = nk.chart.push(&ctx, values[it]);
                    it += 1;
                }
            }
            // add label
            nk.text.label(&ctx, "text at end", nk.text.Align.mid_left);
        }
        nk.window.end(&ctx);

        // Draw
        try nkSDL.render(&ctx, win, 0);
    }
}
