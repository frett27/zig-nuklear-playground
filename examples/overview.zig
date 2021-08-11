const std = @import("std");
const nk = @import("zig-nuklear");

var show_menu = true;
var titlebar = true;
var border = true;
var resize = true;
var movable = true;
var no_scrollbar = false;
var scale_left = false;
var minimizable = true;

// static enum nk_style_header_align header_align = NK_HEADER_RIGHT;

const menu_state = enum {
    MENU_NONE,
    MENU_FILE,
    MENU_EDIT,
    MENU_VIEW,
    MENU_CHART,
};

const MenuState = struct {
    mprog: usize,
    mslider: i32,
    mcheck: bool,

    prog: usize,
    slider: i32,
    check: bool,

    advState: menu_state,
};

var menuState: MenuState = .{
    .mprog = 60,
    .mslider = 10,
    .mcheck = true,

    .prog = 60,
    .slider = 10,
    .check = true,
    .advState = menu_state.MENU_NONE,
};

var show_app_about = false;

pub fn menu(ctx: *nk.Context) void {

    // menubar
    const menu_states = enum { MENU_DEFAULT, MENU_WINDOWS };
    nk.menubar.begin(ctx);
    defer nk.menubar.end(ctx);

    // menu #1
    nk.layout.rowBegin(ctx, .NK_STATIC, 25, 5);
    nk.layout.rowPush(ctx, 45);
    if (nk.menu.beginLabel(ctx, "MENU", nk.text.Align.mid_left, nk.vec2(120, 200))) {
        defer nk.menu.end(ctx);
        nk.layout.rowDynamic(ctx, 25, 1);
        if (nk.menu.itemLabel(ctx, "Hide", nk.text.Align.mid_left))
            show_menu = false;
        if (nk.menu.itemLabel(ctx, "About", nk.text.Align.mid_left))
            show_app_about = true;
        _ = nk.bar.progress(ctx, &menuState.prog, 100, true);
        _ = nk.slider.int(ctx, 0, &menuState.slider, 16, 1);
        _ = nk.checkbox.label(ctx, "check", &menuState.check);
    }
    // menu #2
    nk.layout.rowPush(ctx, 60);
    if (nk.menu.beginLabel(ctx, "ADVANCED", nk.text.Align.mid_left, nk.vec2(200, 600))) {
        var state: nk.CollapseStates = undefined;

        state = if (menuState.advState == menu_state.MENU_FILE) .NK_MAXIMIZED else .NK_MINIMIZED;
        if (nk.tree.statePush(ctx, .NK_TREE_TAB, "FILE", &state)) {
            defer nk.tree.pop(ctx);
            menuState.advState = menu_state.MENU_FILE;
            _ = nk.menu.itemLabel(ctx, "New", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Open", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Save", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Close", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Exit", nk.text.Align.mid_left);
        } else menuState.advState = if (menuState.advState == menu_state.MENU_FILE) menu_state.MENU_NONE else menuState.advState;

        state = if (menuState.advState == menu_state.MENU_EDIT) .NK_MAXIMIZED else .NK_MINIMIZED;
        if (nk.tree.statePush(ctx, .NK_TREE_TAB, "EDIT", &state)) {
            menuState.advState = menu_state.MENU_EDIT;
            _ = nk.menu.itemLabel(ctx, "Copy", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Delete", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Cut", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Paste", nk.text.Align.mid_left);
            nk.tree.pop(ctx);
        } else menuState.advState = if (menuState.advState == menu_state.MENU_EDIT) menu_state.MENU_NONE else menuState.advState;

        state = if (menuState.advState == menu_state.MENU_VIEW) .NK_MAXIMIZED else .NK_MINIMIZED;
        if (nk.tree.statePush(ctx, .NK_TREE_TAB, "VIEW", &state)) {
            menuState.advState = menu_state.MENU_VIEW;
            _ = nk.menu.itemLabel(ctx, "About", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Options", nk.text.Align.mid_left);
            _ = nk.menu.itemLabel(ctx, "Customize", nk.text.Align.mid_left);
            nk.tree.pop(ctx);
        } else menuState.advState = if (menuState.advState == .MENU_VIEW) menu_state.MENU_NONE else menuState.advState;

        state = if (menuState.advState == .MENU_CHART) .NK_MAXIMIZED else .NK_MINIMIZED;
        if (nk.tree.statePush(ctx, .NK_TREE_TAB, "CHART", &state)) {
            defer nk.tree.pop(ctx);
            var i: usize = 0;
            const values = [_]f32{ 26.0, 13.0, 30.0, 15.0, 25.0, 10.0, 20.0, 40.0, 12.0, 8.0, 22.0, 28.0 };
            menuState.advState = menu_state.MENU_CHART;
            nk.layout.rowDynamic(ctx, 150, 1);

            _ = nk.chart.begin(ctx, .NK_CHART_COLUMN, values.len, 0, 50);
            defer nk.chart.end(ctx);

            i = 0;
            while (i < values.len) {
                _ = nk.chart.push(ctx, values[i]);
                i += 1;
            }
        } else menuState.advState = if (menuState.advState == menu_state.MENU_CHART) menu_state.MENU_NONE else menuState.advState;
        nk.menu.end(ctx);
    }

    // menu widgets
    nk.layout.rowPush(ctx, 70);
    _ = nk.bar.progress(ctx, &menuState.mprog, 100, true);
    _ = nk.slider.int(ctx, 0, &menuState.mslider, 16, 1);
    _ = nk.checkbox.label(ctx, "check", &menuState.mcheck);
}

const StateTkInput = struct {
    ratio: [2]f32,
    field_buffer: [64]u8,
    text: [9][64]u8,
    text_len: [9]usize,

    box_buffer: [512]u8,
    field_len: usize,
    box_len: usize,
    active: nk.Flags,
};

var stateTkInput: StateTkInput = .{
    .ratio = [2]f32{ 120, 150 },
    .field_buffer = undefined,
    .text = undefined,
    .text_len = undefined,
    .box_buffer = undefined,
    .field_len = undefined,
    .box_len = undefined,
    .active = undefined,
};

fn tkInput(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Input", NK_MINIMIZED)) {
        defer nk.tree.pop(ctx);

        nk.layout.row(ctx, .NK_STATIC, 25, 2, stateTkInput.ratio);
        nk.text.label(ctx, "Default:", nk.text.Align.mid_left);

        nk.edit.string(ctx, .NK_EDIT_SIMPLE, stateTkInput.text[0], &stateTkInput.text_len[0], 64, nk.rest.nkFilterDefault);
        nk.text.label(ctx, "Int:", nk.text.Align.mid_left);
        nk.edit.string(ctx, .NK_EDIT_SIMPLE, stateTkInput.text[1], &stateTkInput.text_len[1], 64, nk.rest.nkFilterDecimal);
        nk.text.label(ctx, "Float:", nk.text.Align.mid_left);
        nk.edit.string(ctx, .NK_EDIT_SIMPLE, stateTkInput.text[2], &stateTkInput.text_len[2], 64, nk.rest.nkFilterFloat);
        nk.text.label(ctx, "Hex:", nk.text.Align.mid_left);
        nk.edit.string(ctx, .NK_EDIT_SIMPLE, stateTkInput.text[4], &stateTkInput.text_len[4], 64, nk.rest.nkFilterHex);
        nk.text.label(ctx, "Octal:", nk.text.Align.mid_left);
        nk.edit.string(ctx, .NK_EDIT_SIMPLE, stateTkInput.text[5], &stateTkInput.text_len[5], 64, nk.rest.nkFilterOct);
        nk.text.label(ctx, "Binary:", nk.text.Align.mid_left);
        nk.edit.string(ctx, .NK_EDIT_SIMPLE, stateTkInput.text[6], &stateTkInput.text_len[6], 64, nk.rest.nkFilterBinary);

        nk.text.label(ctx, "Password:", nk.text.Align.mid_left);
        {
            var i: usize = 0;
            var old_len: u32 = text_len[8];
            var buffer: [64]u8 = undefined;

            while (i < stateTkInput.text_len[8]) : (i += 1) {
                buffer[i] = '*';
            }
            nk.edit.string(ctx, .NK_EDIT_FIELD, buffer, &stateTkInput.text_len[8], 64, nk.rest.nkFilterDefault);

            if (old_len < text_len[8])
                memcpy(&stateTkInput.text[8][stateTkInput.old_len], &stateTkInput.buffer[stateTkInput.old_len], @intCast(usize, (stateTkInput.text_len[8] - stateTkInput.old_len)));
        }

        nk.text.label(ctx, "Field:", nk.text.Align.mid_left);
        nk.edit.string(ctx, NK_EDIT_FIELD, stateTkInput.field_buffer, &stateTkInput.field_len, 64, nk.rest.nkFilterDefault);

        nk.text.label(ctx, "Box:", nk.text.Align.mid_left);
        nk.layout.rowStatic(ctx, 180, 278, 1);
        nk.edit.string(ctx, NK_EDIT_BOX, stateTkInput.box_buffer, &stateTkInput.box_len, 512, nk.rest.nkFilterDefault);

        nk.layout.row(ctx, NK_STATIC, 25, 2, ratio);
        active = nk.edit.string(ctx, NK_EDIT_FIELD | NK_EDIT_SIG_ENTER, text[7], &text_len[7], 64, nk.rest.nkFilterAscii);
        if (nk.button.label(ctx, "Submit") or
            (active & NK_EDIT_COMMITED))
        {
            stateTkInput.text[7][stateTkInput.text_len[7]] = '\n';
            stateTkInput.text_len[7] += 1;
            memcpy(&stateTkInput.box_buffer[stateTkInput.box_len], &stateTkInput.text[7], stateTkInput.text_len[7]);
            stateTkInput.box_len += stateTkInput.text_len[7];
            stateTkInput.text_len[7] = 0;
        }
    }
}

var aboutRect: nk.Rect = nk.rect(20, 100, 300, 190);

fn about(ctx: *nk.Context) void {
    // about popup

    if (nk.popup.begin(ctx, .NK_POPUP_STATIC, "About", .{ .closable = true }, aboutRect)) {
        nk.popup.end(ctx);
        nk.layout.rowDynamic(ctx, 20, 1);
        nk.text.label(ctx, "Nuklear", nk.text.Align.mid_left);
        nk.text.label(ctx, "By Micha Mettke", nk.text.Align.mid_left);
        nk.text.label(ctx, "nuklear is licensed under the public domain License.", nk.text.Align.mid_left);
    } else show_app_about = false;
}

const TkWidgetOptions = enum {
    A,
    B,
    C,
};

const ColorMode = enum { COL_RGB, COL_HSV };

const TkWidget = struct {
    checkbox: i32,
    option: TkWidgetOptions,

    // Basic widgets
    int_slider: i32 = 5,
    float_slider: f32 = 2.5,
    prog_value: usize = 40,
    property_float: f32 = 2,
    property_int: i32 = 10,
    property_neg: i32 = 10,

    range_float_min: f32 = 0,
    range_float_max: f32 = 100,
    range_float_value: f32 = 50,
    range_int_min: i32 = 0,
    range_int_value: i32 = 2048,
    range_int_max: i32 = 4096,
    ratio: [2]f32 = [2]f32{ 120, 150 },

    inactive: bool = true,

    chart_selection: f32 = 8.0,
    current_weapon: usize = 0,
    check_values: [5]u32 = undefined,
    position: [3]f32 = undefined,
    combo_color: nk.Color = nk.rest.nkColor(130, 50, 50, 255),
    combo_color2: nk.Colorf = nk.Rest.nkColorF(0.509, 0.705, 0.2, 1.0),

    prog_a: usize = 20,
    prog_b: usize = 40,
    prog_c: usize = 10,
    prog_d: usize = 90,
    
    weapons: [][*:0]const u8 = [_][*:0]u8{ "Fist", "Pistol", "Shotgun", "Plasma", "BFG" },

    list_selected: []bool = [_]bool{ false, false, true, false },

    grid_selected: []u8 = [_]u8{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },

    col_mode: ColorMode,
};

var stateTkWidget: TkWidget = .{};

fn tkWidgets(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, opaque {}, .NK_TREE_TAB, "Widgets", .NK_MINIMIZED)) {
        defer nk.tree.pop(ctx);

        if (nk.tree.push(ctx, opaque {}, .NK_TREE_NODE, "Text", .NK_MINIMIZED)) {
            defer nk.tree.pop(ctx);
            // Text Widgets
            nk.layout.rowDynamic(ctx, 20, 1);
            nk.text.label(ctx, "Label aligned left", nk.text.Align.mid_left);
            nk.text.label(ctx, "Label aligned centered", nk.text.Align.mid_center);
            nk.text.label(ctx, "Label aligned right", nk.text.Align.mid_right);
            nk.text.labelColored(ctx, "Blue text", nk.text.Align.mid_left, nk.rest.nkRgb(0, 0, 255));
            nk.text.labelColored(ctx, "Yellow text", nk.text.Align.mid_left, nk.rest.nkRgb(255, 255, 0));

            nk.text.t(ctx, "Text without /0", 15, nk.text.Align.mid_right);

            nk.layout.rowStatic(ctx, 100, 200, 1);
            nk.text.labelWrap(ctx, "This is a very long line to hopefully get this text to be wrapped into multiple lines to show line wrapping");
            nk.layout.rowDynamic(ctx, 100, 1);
            nk.text.labelWrap(ctx, "This is another long text to show dynamic window changes on multiline text");
        }

        if (nk.tree.push(ctx, opaque {}, .NK_TREE_NODE, "Button", .NK_MINIMIZED)) {
            defer nk.tree.pop(ctx);

            // Buttons Widgets
            nk.layout.rowStatic(ctx, 30, 100, 3);
            if (nk.button.label(ctx, "Button")) {
                std.debug.print("Button pressed!\n", .{});
            }
            nk.button.setBehavior(ctx, .NK_BUTTON_REPEATER);
            if (nk.button.label(ctx, "Repeater"))
            {    std.debug.print("Repeater is being pressed!\n", .{});
            }
            nk.button.setBehavior(ctx, .NK_BUTTON_DEFAULT);
            _=nk.button.color(ctx, nk.rest.nkRgb(0, 0, 255));

            nk.layout.rowStatic(ctx, 25, 25, 8);
            _=nk.button.symbol(ctx, .NK_SYMBOL_CIRCLE_SOLID);
            _=nk.button.symbol(ctx, .NK_SYMBOL_CIRCLE_OUTLINE);
            _=nk.button.symbol(ctx, .NK_SYMBOL_RECT_SOLID);
            _=nk.button.symbol(ctx, .NK_SYMBOL_RECT_OUTLINE);
            _=nk.button.symbol(ctx, .NK_SYMBOL_TRIANGLE_UP);
            _=nk.button.symbol(ctx, .NK_SYMBOL_TRIANGLE_DOWN);
            _=nk.button.symbol(ctx, .NK_SYMBOL_TRIANGLE_LEFT);
            _=nk.button.symbol(ctx, .NK_SYMBOL_TRIANGLE_RIGHT);

            nk.layout.rowStatic(ctx, 30, 100, 2);
            _=nk.button.symbolLabel(ctx, .NK_SYMBOL_TRIANGLE_LEFT, "prev", .NK_TEXT_RIGHT);
            _=nk.button.symbolLabel(ctx, .NK_SYMBOL_TRIANGLE_RIGHT, "next", .NK_TEXT_LEFT);
        
        }

        if (nk.tree.push(ctx, NK_TREE_NODE, "Basic", NK_MINIMIZED)) {
            defer nk.tree.pop(ctx);

            nk.layout.rowStatic(ctx, 30, 100, 1);
            nk.checkbox.label(ctx, "Checkbox", &stateTkWidget.checkbox);

            nk.layout.rowStatic(ctx, 30, 80, 3);
            option = if (nk.option.label(ctx, "optionA", option == A)) A else option;
            option = if (nk.option.label(ctx, "optionB", option == B)) B else option;
            option = if (nk.option.label(ctx, "optionC", option == C)) C else option;

            nk.layout.row(ctx, NK_STATIC, 30, 2, ratio);
            nk.text.labelf(ctx, NK_TEXT_LEFT, "Slider int");
            nk.slider.int(ctx, 0, &int_slider, 10, 1);

            nk.text.label(ctx, "Slider float", NK_TEXT_LEFT);
            nk.slider.float(ctx, 0, &float_slider, 5.0, 0.5);
            nk.text.labelf(ctx, NK_TEXT_LEFT, "Progressbar: %zu", prog_value);
            nk.progress(ctx, &prog_value, 100, NK_MODIFIABLE);

            nk.layout.row(ctx, NK_STATIC, 25, 2, ratio);
            nk.text.label(ctx, "Property float:", NK_TEXT_LEFT);
            nk.property.float(ctx, "Float:", 0, &property_float, 64.0, 0.1, 0.2);
            nk.text.label(ctx, "Property int:", NK_TEXT_LEFT);
            nk.property.int(ctx, "Int:", 0, &property_int, 100, 1, 1);
            nk.text.label(ctx, "Property neg:", NK_TEXT_LEFT);
            nk.property.int(ctx, "Neg:", -10, &property_neg, 10, 1, 1);

            nk.layout.rowDynamic(ctx, 25, 1);
            nk.text.label(ctx, "Range:", NK_TEXT_LEFT);
            nk.layout.rowDynamic(ctx, 25, 3);
            nk.property.float(ctx, "#min:", 0, &range_float_min, range_float_max, 1.0, 0.2);
            nk.property.float(ctx, "#float:", range_float_min, &range_float_value, range_float_max, 1.0, 0.2);
            nk.property.float(ctx, "#max:", range_float_min, &range_float_max, 100, 1.0, 0.2);

            nk.property.int(ctx, "#min:", INT_MIN, &range_int_min, range_int_max, 1, 10);
            nk.property.int(ctx, "#neg:", range_int_min, &range_int_value, range_int_max, 1, 10);
            nk.property.int(ctx, "#max:", range_int_min, &range_int_max, INT_MAX, 1, 10);
        }

        if (nk.tree.push(ctx, NK_TREE_NODE, "Inactive", NK_MINIMIZED)) {
            defer nk.tree.pop(ctx);

            nk.layout.rowDynamic(ctx, 30, 1);
            nk.checkbox.label(ctx, "Inactive", &inactive);

            nk.layout.rowStatic(ctx, 30, 80, 1);
            if (inactive) {
                var button: nk.Buttons = undefined;
                button = ctx.style.button;
                ctx.style.button.normal = nk.style.itemColor(nk.rest.nkRgb(40, 40, 40));
                ctx.style.button.hover = nk.style.itemColor(nk.rest.nkRgb(40, 40, 40));
                ctx.style.button.active = nk.style.itemColor(nk.rest.nkRgb(40, 40, 40));
                ctx.style.button.border_color = nk.rest.nkRgb(60, 60, 60);
                ctx.style.button.text_background = nk.rest.nkRgb(60, 60, 60);
                ctx.style.button.text_normal = nk.rest.nkRgb(60, 60, 60);
                ctx.style.button.text_hover = nk.rest.nkRgb(60, 60, 60);
                ctx.style.button.text_active = nk.rest.nkRgb(60, 60, 60);
                nk.button.label(ctx, "button");
                ctx.style.button = button;
            } else if (nk.button.label(ctx, "button"))
                std.debug.print("button pressed\n", .{});
        }

        if (nk.tree.push(ctx, NK_TREE_NODE, "Selectable", NK_MINIMIZED)) {
            defer nk.tree.pop(ctx);
            if (nk.tree.push(ctx, NK_TREE_NODE, "List", NK_MINIMIZED)) {
                defer nk.tree.pop(ctx);
                nk.layout.rowStatic(ctx, 18, 100, 1);
                nk.selectable.label(ctx, "Selectable", NK_TEXT_LEFT, &list_selected[0]);
                nk.selectable.label(ctx, "Selectable", NK_TEXT_LEFT, &list_selected[1]);
                nk.text.label(ctx, "Not Selectable", NK_TEXT_LEFT);
                nk.selectable.label(ctx, "Selectable", NK_TEXT_LEFT, &list_selected[2]);
                nk.selectable.label(ctx, "Selectable", NK_TEXT_LEFT, &list_selected[3]);
            }
            if (nk.tree.push(ctx, NK_TREE_NODE, "Grid", NK_MINIMIZED)) {
                defer nk.tree.pop(ctx);
                nk.layout.rowStatic(ctx, 50, 50, 4);
                var i: u32 = 0;
                while (i < 16) {
                    if (nk.selectable.label(ctx, "Z", NK_TEXT_CENTERED, &grid_selected[i])) {
                        var x: i32 = @mod(i, 4);
                        var y: i32 = @divFloor(i, 4);
                        if (x > 0) selected[i - 1] ^= 1;
                        if (x < 3) selected[i + 1] ^= 1;
                        if (y > 0) selected[i - 4] ^= 1;
                        if (y < 3) selected[i + 4] ^= 1;
                    }

                    i += 1;
                }
            }
        }

        if (nk.tree.push(ctx, NK_TREE_NODE, "Combo", NK_MINIMIZED)) {
            //  Combobox Widgets
            //   In this library comboboxes are not limited to being a popup
            //   list of selectable text. Instead it is a abstract concept of
            //   having something that is *selected* or displayed, a popup window
            //   which opens if something needs to be modified and the content
            //   of the popup which causes the *selected* or displayed value to
            //   change or if wanted close the combobox.

            //   While strange at first handling comboboxes in a abstract way
            //   solves the problem of overloaded window content. For example
            //   changing a color value requires 4 value modifier (slider, property,...)
            //   for RGBA then you need a label and ways to display the current color.
            //   If you want to go fancy you even add rgb and hsv ratio boxes.
            //   While fine for one color if you have a lot of them it because
            //   tedious to look at and quite wasteful in space. You could add
            //   a popup which modifies the color but this does not solve the
            //   fact that it still requires a lot of cluttered space to do.

            //   In these kind of instance abstract comboboxes are quite handy. All
            //   value modifiers are hidden inside the combobox popup and only
            //   the color is shown if not open. This combines the clarity of the
            //   popup with the ease of use of just using the space for modifiers.

            //   Other instances are for example time and especially date picker,
            //   which only show the currently activated time/data and hide the
            //   selection logic inside the combobox popup.

            var buffer: [64]u8 = undefined;
            var sum: usize = 0;

            // default combobox
            nk.layout.rowStatic(ctx, 25, 200, 1);

            current_weapon = nk.combo(ctx, weapons, NK_LEN(weapons), current_weapon, 25, nk.vec2(200, 200));

            // slider color combobox
            if (nk.combo.beginColor(ctx, combo_color, nk.vec2(200, 200))) {
                defer nk.combo.end(ctx);

                var ratios: []f32 = [_]f32{ 0.15, 0.85 };
                nk.layout.row(ctx, NK_DYNAMIC, 30, 2, ratios);
                nk.text.label(ctx, "R:", NK_TEXT_LEFT);
                combo_color.r = @truncate(u8, nk.slide.int(ctx, 0, combo_color.r, 255, 5));
                nk.text.label(ctx, "G:", NK_TEXT_LEFT);
                combo_color.g = @truncate(u8, nk.slide.int(ctx, 0, combo_color.g, 255, 5));
                nk.text.label(ctx, "B:", NK_TEXT_LEFT);
                combo_color.b = @truncate(u8, nk.slide.int(ctx, 0, combo_color.b, 255, 5));
                nk.text.label(ctx, "A:", NK_TEXT_LEFT);
                combo_color.a = @truncate(u8, nk.slide.int(ctx, 0, combo_color.a, 255, 5));
            }
            // complex color combobox
            if (nk.combo.begin.color(ctx, nk.rest.nkRgb_cf(combo_color2), nk.vec2(200, 400))) {
                defer nk.combo.end(ctx);

                stateTkWidget.col_mode = COL_RGB;
                // #ifndef DEMO_DO_NOT_USE_COLOR_PICKER
                nk.layout.rowDynamic(ctx, 120, 1);
                combo_color2 = nk.color.picker(ctx, combo_color2, nk.rest.nkRgbA);
                // #endif

                nk.layout.rowDynamic(ctx, 25, 2);
                col_mode = if (nk.option.label(ctx, "RGB", stateTkWidget.col_mode == COL_RGB)) COL_RGB else stateTkWidget.col_mode;
                col_mode = if (nk.option.label(ctx, "HSV", stateTkWidget.col_mode == COL_HSV)) COL_HSV else stateTkWidget.col_mode;

                nk.layout.rowDynamic(ctx, 25, 1);
                if (stateTkWidget.col_mode == COL_RGB) {
                    combo_color2.r = nk.property.f(ctx, "#R:", 0, combo_color2.r, 1.0, 0.01, 0.005);
                    combo_color2.g = nk.property.f(ctx, "#G:", 0, combo_color2.g, 1.0, 0.01, 0.005);
                    combo_color2.b = nk.property.f(ctx, "#B:", 0, combo_color2.b, 1.0, 0.01, 0.005);
                    combo_color2.a = nk.property.f(ctx, "#A:", 0, combo_color2.a, 1.0, 0.01, 0.005);
                } else {
                    var hsva = [4]f32;
                    nk.rest.nkColorfHsvaFv(hsva, combo_color2);
                    hsva[0] = nk.property.f(ctx, "#H:", 0, hsva[0], 1.0, 0.01, 0.05);
                    hsva[1] = nk.property.f(ctx, "#S:", 0, hsva[1], 1.0, 0.01, 0.05);
                    hsva[2] = nk.property.f(ctx, "#V:", 0, hsva[2], 1.0, 0.01, 0.05);
                    hsva[3] = nk.property.f(ctx, "#A:", 0, hsva[3], 1.0, 0.01, 0.05);
                    combo_color2 = nk.rest.nkHsvaColorfv(hsva);
                }
            }
            // progressbar combobox
            sum = prog_a + prog_b + prog_c + prog_d;
            sprintf(buffer, "%lu", sum);
            if (nk.combo.beginLabel(ctx, buffer, nk.vec2(200, 200))) {
                defer nk.combo.end(ctx);
                nk.layout.rowDynamic(ctx, 30, 1);
                nk.progress(ctx, &prog_a, 100, NK_MODIFIABLE);
                nk.progress(ctx, &prog_b, 100, NK_MODIFIABLE);
                nk.progress(ctx, &prog_c, 100, NK_MODIFIABLE);
                nk.progress(ctx, &prog_d, 100, NK_MODIFIABLE);
            }

            // checkbox combobox
            sum = (size_t)(check_values[0] + check_values[1] + check_values[2] + check_values[3] + check_values[4]);
            sprintf(buffer, "%lu", sum);
            if (nk.combo.beginLabel(ctx, buffer, nk.vec2(200, 200))) {
                defer nk.combo.end(ctx);
                nk.layout.rowDynamic(ctx, 30, 1);
                nk.checkbox.label(ctx, weapons[0], &check_values[0]);
                nk.checkbox.label(ctx, weapons[1], &check_values[1]);
                nk.checkbox.label(ctx, weapons[2], &check_values[2]);
                nk.checkbox.label(ctx, weapons[3], &check_values[3]);
            }

            // complex text combobox
            sprintf(buffer, "%.2f, %.2f, %.2f", position[0], position[1], position[2]);
            if (nk.combo.beginLabel(ctx, buffer, nk.vec2(200, 200))) {
                defer nk.combo.end(ctx);
                nk.layout.rowDynamic(ctx, 25, 1);
                nk.property.float(ctx, "#X:", -1024.0, &position[0], 1024.0, 1, 0.5);
                nk.property.float(ctx, "#Y:", -1024.0, &position[1], 1024.0, 1, 0.5);
                nk.property.float(ctx, "#Z:", -1024.0, &position[2], 1024.0, 1, 0.5);
            }

            // chart combobox
            sprintf(buffer, "%.1f", chart_selection);
            if (nk.combo.beginLabel(ctx, buffer, nk.vec2(200, 250))) {
                defer nk.combo.end(ctx);

                var i: usize = 0;
                const values = [_]f32{ 26.0, 13.0, 30.0, 15.0, 25.0, 10.0, 20.0, 40.0, 12.0, 8.0, 22.0, 28.0, 5.0 };

                nk.layout.rowDynamic(ctx, 150, 1);
                nk.chart.begin(ctx, NK_CHART_COLUMN, NK_LEN(values), 0, 50);
                defer nk.chart.end(ctx);

                while (i < values.len) : (i += 1) {
                    var res = nk.chart.push(ctx, values[i]);
                    if (res & NK_CHART_CLICKED) {
                        chart_selection = values[i];
                        nk.combo.close(ctx);
                    }
                }
            }

            dateTime(ctx);

            nk.tree.pop(ctx);
        }

        tkInput(ctx);
    }
}

const TkStateDateTime = struct {
    time_selected: u32 = 0,
    date_selected: u32 = 0,
    sel_time: tm = undefined,
    sel_date: tm = undefined,
};

var tkStateDateTime: TkStateDateTime = .{};

fn dateTime(ctx: *nk.Context) void {
    if (!time_selected or !date_selected) {
        // keep time and date updated if nothing is selected
        var cur_time: time_t = time(0);
        var n: *tm = localtime(&cur_time);
        if (!time_selected)
            memcpy(&sel_time, n, sizeof(tm));
        if (!date_selected)
            memcpy(&sel_date, n, sizeof(tm));
    }

    // time combobox
    sprintf(buffer, "%02d:%02d:%02d", sel_time.tm_hour, sel_time.tm_min, sel_time.tm_sec);
    if (nk.combo.begin.label(ctx, buffer, nk.vec2(200, 250))) {
        defer nk_combo_end(ctx);
        time_selected = 1;
        nk.layout.rowDynamic(ctx, 25, 1);
        sel_time.tm_sec = nk.property.i(ctx, "#S:", 0, sel_time.tm_sec, 60, 1, 1);
        sel_time.tm_min = nk.property.i(ctx, "#M:", 0, sel_time.tm_min, 60, 1, 1);
        sel_time.tm_hour = nk.property.i(ctx, "#H:", 0, sel_time.tm_hour, 23, 1, 1);
    }

    // date combobox
    sprintf(buffer, "%02d-%02d-%02d", sel_date.tm_mday, sel_date.tm_mon + 1, sel_date.tm_year + 1900);
    if (nk.combo.begin.label(ctx, buffer, nk.vec2(350, 400))) {
        defer nk.combo.end(ctx);
        var i: i32 = 0;
        const month = [_][*c]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
        const week_days = [_][*c]const u8{ "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" };
        const month_days = [_]u16{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        const year = sel_date.tm_year + 1900;
        const leap_year = (!@mod(year, 4) and (@mod(year, 100))) or !@mod(year, 400);
        const days: i16 = if (sel_date.tm_mon == 1)
            (month_days[sel_date.tm_mon] + leap_year)
        else
            month_days[sel_date.tm_mon];

        // header with month and year
        date_selected = 1;
        nk.layout.rowBegin(ctx, NK_DYNAMIC, 20, 3);
        nk.layout.rowPush(ctx, 0.05);

        if (nk.button.symbol(ctx, NK_SYMBOL_TRIANGLE_LEFT)) {
            if (sel_date.tm_mon == 0) {
                sel_date.tm_mon = 11;
                sel_date.tm_year = std.math.max(0, sel_date.tm_year - 1);
            } else {
                sel_date.tm_mon -= 1;
            }
        }

        nk.layout.rowPush(ctx, 0.9);
        sprintf(buffer, "%s %d", month[sel_date.tm_mon], year);
        nk.text.label(ctx, buffer, NK_TEXT_CENTERED);
        nk.layout.rowPush(ctx, 0.05);
        if (nk.button.symbol(ctx, NK_SYMBOL_TRIANGLE_RIGHT)) {
            if (sel_date.tm_mon == 11) {
                sel_date.tm_mon = 0;
                sel_date.tm_year += 1;
            } else {
                sel_date.tm_mon += 1;
            }
        }
        nk.layout.rowEnd(ctx);

        // good old week day formula (double because precision)
        {
            var year_n = if (sel_date.tm_mon < 2) year - 1 else year;
            var y = @mod(year_n, 100);
            var c = @divFloor(year_n, 100);
            var y4 = @floatToInt(i32, @intToFloat(f32, y) / 4);
            var c4 = @floatToInt(i32, @intToFloat(f32, c) / 4);

            var m = @floatToInt(i32, 2.6 *
                @intToFloat(f32, ((@mod(sel_date.tm_mon + 10, 12) + 1))) - 0.2);
            var week_day = @mod((@mod((1 + m + y + y4 + c4 - 2 * c), 7) + 7), 7);

            // weekdays
            nk.layout.rowDynamic(ctx, 35, 7);

            i = 0;

            while (i < week_days.len) : (i += 1) {
                nk.text.label(ctx, week_days[i], NK_TEXT_CENTERED);
            }
            // days
            if (week_day > 0) nk_spacing(ctx, week_day);
            i = 1;
            while (i <= days) {
                sprintf(buffer, "%d", i);
                if (nk.button.label(ctx, buffer)) {
                    sel_date.tm_mday = i;
                    nk.combo.close(ctx);
                }

                i += 1;
            }
        }
    }
}

const TkStateCharts = struct {
    col_index: i32 = -1,
    line_index: i32 = -1,
};
var tkStateCharts: TkStateCharts = .{};

fn tkCharts(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, opaque {}, .NK_TREE_TAB, "Chart", .NK_MINIMIZED)) {
        defer nk.tree.pop(ctx);

        // Chart Widgets
        //  This library has two different rather simple charts. The line and the
        //   column chart. Both provide a simple way of visualizing values and
        //   have a retained mode and immediate mode API version. For the retain
        //   mode version `nk_plot` and `nk_plot_function` you either provide
        //   an array or a callback to call to handle drawing the graph.
        //   For the immediate mode version you start by calling `nk_chart_begin`
        //   and need to provide min and max values for scaling on the Y-axis.
        //   and then call `nk_chart_push` to push values into the chart.
        //   Finally `nk.chart.end` needs to be called to end the process. */
        var id: f32 = 0;
        var step: f32 = (2.0 * 3.141592654) / 32.0;

        var i: usize = 0;
        var index: i32 = -1;
        var bounds: nk.Rect = undefined;

        // line chart
        id = 0;
        index = -1;
        nk.layout.rowDynamic(ctx, 100, 1);
        bounds = nk.widget.bounds(ctx);
        if (nk.chart.begin(ctx, .NK_CHART_LINES, 32, -1.0, 1.0)) {
            defer nk.chart.end(ctx);

            while (i < 32) : (i += 1) {
                var res: nk.Flags = nk.chart.push(ctx, std.math.cos(id));
                if ((res & @enumToInt(.NK_CHART_HOVERING)) != 0) {
                    index = i;
                }
                if ((res & @enumToInt(.NK_CHART_CLICKED)) != 0) {
                    tkStateCharts.line_index = i;
                }
                id += step;
            }
        }

        if (index != -1) {
            nk.tooltip.f(ctx, "Value: %.2f", std.math.cos(@intToFloat(f32, index) * step));
        }
        if (line_index != -1) {
            nk.layout.rowDynamic(ctx, 20, 1);
            nk.text.labelf(ctx, NK_TEXT_LEFT, "Selected value: %.2f", std.math.cos(@intToFloat(f32, index) * step));
        }

        // column chart
        nk.layout.rowDynamic(ctx, 100, 1);
        bounds = nk.widget.bounds(ctx);
        if (nk.chart.begin(ctx, NK_CHART_COLUMN, 32, 0.0, 1.0)) {
            defer nk.chart.end(ctx);
            i = 0;

            while (i < 32) : (i += 1) {
                var res = nk.chart.push(ctx, std.math.fabs(std.math.sin(id)));
                if (res & NK_CHART_HOVERING)
                    index = i;
                if (res & NK_CHART_CLICKED)
                    col_index = i;
                id += step;
            }
        }
        if (index != -1) {
            nk_tooltipf(ctx, "Value: %.2f", std.math.fabs(std.math.sin(step * @intToFloat(f32, index))));
        }
        if (col_index != -1) {
            nk.layout.rowDynamic(ctx, 20, 1);

            nk.text.labelf(ctx, NK_TEXT_LEFT, "Selected value: %.2f", std.math.fabs(std.math.sin(step * @intToFloat(f32, col_index))));
        }

        // mixed chart
        nk.layout.rowDynamic(ctx, 100, 1);
        bounds = nk.widget.bounds(ctx);
        if (nk.chart.begin(ctx, NK_CHART_COLUMN, 32, 0.0, 1.0)) {
            defer nk.chart.end(ctx);
            nk.chart.add_slot(ctx, NK_CHART_LINES, 32, -1.0, 1.0);
            nk.chart.add_slot(ctx, NK_CHART_LINES, 32, -1.0, 1.0);
            id = 0;
            i = 0;
            while (i < 32) : (i += 1) {
                nk.chart.pushSlot(ctx, std.math.fabs(std.math.sin(id)), 0);
                nk.chart.pushSlot(ctx, std.math.cos(id), 1);
                nk.chart.pushSlot(ctx, std.math.sin(id), 2);
                id += step;
            }
        }

        // mixed colored chart
        nk.layout.rowDynamic(ctx, 100, 1);
        bounds = nk.widget.bounds(ctx);
        if (nk.chart.beginColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(255, 0, 0), nk.rest.nkRgb(150, 0, 0), 32, 0.0, 1.0)) {
            defer nk.chart.end(ctx);
            nk.chart.addSlotColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(0, 0, 255), nk.rest.nkRgb(0, 0, 150), 32, -1.0, 1.0);
            nk.chart.addSlotColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(0, 255, 0), nk.rest.nkRgb(0, 150, 0), 32, -1.0, 1.0);

            id = 0;
            i = 0;

            while (i < 32) : (i += 1) {
                nk.chart.pushSlot(ctx, std.math.fabs(std.math.sin(id)), 0);
                nk.chart.pushSlot(ctx, std.math.cos(id), 1);
                nk.chart.pushSlot(ctx, std.math.sin(id), 2);
                id += step;
            }
        }
    }
}

const HTNState = struct {
    a: f32,
    b: f32,
    c: f32,
};

var htnState: HTNState = .{ .a = 100, .b = 100, .c = 100 };

fn horizontalTn(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Horizontal", NK_MINIMIZED)) {
        defer nk.tree.pop(ctx);
        var bounds: nk.Rect = undefined;

        // header
        nk.layout.rowStatic(ctx, 30, 100, 2);
        nk.text.label(ctx, "top:", NK_TEXT_LEFT);
        nk.slider.float(ctx, 10.0, &htnState.a, 200.0, 10.0);

        nk.text.label(ctx, "middle:", NK_TEXT_LEFT);
        nk.slider.float(ctx, 10.0, &htnState.b, 200.0, 10.0);

        nk.text.label(ctx, "bottom:", NK_TEXT_LEFT);
        nk.slider.float(ctx, 10.0, &htnState.c, 200.0, 10.0);

        // top space
        nk.layout.rowDynamic(ctx, htnState.a, 1);
        if (nk.group.begin(ctx, "top", NK_WINDOW_NO_SCROLLBAR | NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);
            nk.layout.rowDynamic(ctx, 25, 3);
            nk.button.label(ctx, "#FFAA");
            nk.button.label(ctx, "#FFBB");
            nk.button.label(ctx, "#FFCC");
            nk.button.label(ctx, "#FFDD");
            nk.button.label(ctx, "#FFEE");
            nk.button.label(ctx, "#FFFF");
        }

        // scaler
        nk.layout.rowDynamic(ctx, 8, 1);
        bounds = nk.widget.bounds(ctx);
        nk.spacing(ctx, 1);
        if ((nk.input.isMouseHoveringRect(in, bounds) or
            nk.input.isMousePrevHoveringRect(in, bounds)) and
            nk.input.isMouseDown(&in, .NK_BUTTON_LEFT))
        {
            htnState.a = htnState.a + in.mouse.delta.y;
            htnState.b = htnState.b - in.mouse.delta.y;
        }

        // middle space
        nk.layout.rowDynamic(ctx, htnState.b, 1);
        if (nk.group.begin(ctx, "middle", NK_WINDOW_NO_SCROLLBAR | NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);
            nk.layout.rowDynamic(ctx, 25, 3);
            nk.button.label(ctx, "#FFAA");
            nk.button.label(ctx, "#FFBB");
            nk.button.label(ctx, "#FFCC");
            nk.button.label(ctx, "#FFDD");
            nk.button.label(ctx, "#FFEE");
            nk.button.label(ctx, "#FFFF");
        }

        {
            // scaler
            nk.layout.rowDynamic(ctx, 8, 1);
            bounds = nk.widget.bounds(ctx);
            if ((nk.input.isMouseHoveringRect(&in, bounds) or
                nk.input.isMousePrevHoveringRect(&in, bounds)) and
                nk.input.isMouseDown(&in, .NK_BUTTON_LEFT))
            {
                htnState.b = htnState.b + in.mouse.delta.y;
                htnState.c = htnState.c - in.mouse.delta.y;
            }
        }

        // bottom space
        nk.layout.rowDynamic(ctx, htnState.c, 1);
        if (nk.group.begin(ctx, "bottom", NK_WINDOW_NO_SCROLLBAR | NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);

            nk.layout.rowDynamic(ctx, 25, 3);
            nk.button.label(ctx, "#FFAA");
            nk.button.label(ctx, "#FFBB");
            nk.button.label(ctx, "#FFCC");
            nk.button.label(ctx, "#FFDD");
            nk.button.label(ctx, "#FFEE");
            nk.button.label(ctx, "#FFFF");
        }
    }
}

const TKStateSplitter = struct {
    a: f32 = 100,
    b: f32 = 100,
    c: f32 = 100,
};

var tkStateSplitter: TKStateSplitter = .{};

fn tkSplitter(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Splitter", NK_MINIMIZED)) {
        defer nk.tree.pop(ctx);

        const in: *nk.Input = &ctx.input;
        nk.layout.rowStatic(ctx, 20, 320, 1);
        nk.text.label(ctx, "Use slider and spinner to change tile size", NK_TEXT_LEFT);
        nk.text.label(ctx, "Drag the space between tiles to change tile ratio", NK_TEXT_LEFT);

        if (nk.tree.push(ctx, NK_TREE_NODE, "Vertical", NK_MINIMIZED)) {
            var bounds: nk.Rect = undefined;

            var row_layout: [5]f32 = undefined;
            row_layout[0] = tkStateSplitter.a;
            row_layout[1] = 8;
            row_layout[2] = tkStateSplitter.b;
            row_layout[3] = 8;
            row_layout[4] = tkStateSplitter.c;

            // header
            nk.layout.rowStatic(ctx, 30, 100, 2);
            nk.text.label(ctx, "left:", nk.text.Align.mid_left);
            nk.slider.float(ctx, 10.0, &tkStateSplitter.a, 200.0, 10.0);

            nk.text.label(ctx, "middle:", nk.text.Align.mid_left);
            nk.slider.float(ctx, 10.0, &tkStateSplitter.b, 200.0, 10.0);

            nk.text.label(ctx, "right:", nk.text.Align.mid_left);
            nk.slider.float(ctx, 10.0, &tkStateSplitter.c, 200.0, 10.0);

            // tiles
            nk.layout.row(ctx, NK_STATIC, 200, 5, row_layout);

            // left space
            if (nk.group.begin(ctx, "left", NK_WINDOW_NO_SCROLLBAR | NK_WINDOW_BORDER | NK_WINDOW_NO_SCROLLBAR)) {
                defer nk.group.end(ctx);
                nk.layout.rowDynamic(ctx, 25, 1);
                nk.button.label(ctx, "#FFAA");
                nk.button.label(ctx, "#FFBB");
                nk.button.label(ctx, "#FFCC");
                nk.button.label(ctx, "#FFDD");
                nk.button.label(ctx, "#FFEE");
                nk.button.label(ctx, "#FFFF");
            }

            // scaler
            bounds = nk.widget.bounds(ctx);
            nk.spacing(ctx, 1);
            if ((nk.input.isMouseHoveringRect(in, bounds) or
                nk.input.isMousePrevHoveringRect(in, bounds)) and
                nk.input.isMouseDown(in, NK_BUTTON_LEFT))
            {
                a = row_layout[0] + in.mouse.delta.x;
                b = row_layout[2] - in.mouse.delta.x;
            }

            // middle space
            if (nk.group.begin(ctx, "center", NK_WINDOW_BORDER | NK_WINDOW_NO_SCROLLBAR)) {
                defer nk.group.end(ctx);
                nk.layout.rowDynamic(ctx, 25, 1);
                nk.button.label(ctx, "#FFAA");
                nk.button.label(ctx, "#FFBB");
                nk.button.label(ctx, "#FFCC");
                nk.button.label(ctx, "#FFDD");
                nk.button.label(ctx, "#FFEE");
                nk.button.label(ctx, "#FFFF");
            }

            // scaler
            bounds = nk.widget.bounds(ctx);
            nk_spacing(ctx, 1);
            if ((nk.input.isMouseHoveringRect(in, bounds) or
                nk.input.isMousePrevHoveringRect(in, bounds)) and
                nk.input.isMouseDown(in, NK_BUTTON_LEFT))
            {
                b = (row_layout[2] + in.mouse.delta.x);
                c = (row_layout[4] - in.mouse.delta.x);
            }

            // right space
            if (nk.group.begin(ctx, "right", NK_WINDOW_BORDER | NK_WINDOW_NO_SCROLLBAR)) {
                defer nk.group.end(ctx);

                nk.layout.rowDynamic(ctx, 25, 1);
                nk.button.label(ctx, "#FFAA");
                nk.button.label(ctx, "#FFBB");
                nk.button.label(ctx, "#FFCC");
                nk.button.label(ctx, "#FFDD");
                nk.button.label(ctx, "#FFEE");
                nk.button.label(ctx, "#FFFF");
            }

            nk.tree.pop(ctx);
        }

        horizontalTn(ctx);
    }
}

const TkStatePopup = struct {
    color: nk.Color,
    select: [4]bool,
    popup_active: bool = false,
    prog: u32 = 40,
    slider: u32 = 10,
    popup_s: nk.Rect,
};

var tkStatePopup: TkStatePopup = .{
    .color = nk.rest.nkRgba(255, 0, 0, 255),
    .popup_s = nk.rect(20, 100, 220, 90),
};

fn tkPopup(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, opaque {}, .NK_TREE_TAB, "Popup", .NK_MINIMIZED)) {
        defer nk.tree.pop(ctx);

        const in: *nk.Input = &ctx.input;
        var bounds: nk.Rect = undefined;

        // menu contextual
        nk.layout.rowStatic(ctx, 30, 160, 1);
        bounds = nk.widget.bounds(ctx);
        nk.text.label(ctx, "Right click me for menu", nk.text.Align.mid_left);

        if (nk.contextual.begin(ctx, 0, nk.vec2(100, 300), bounds)) {
            defer nk.contextual.end(ctx);
            nk.layout.rowDynamic(ctx, 25, 1);
            _ = nk.checkbox.label(ctx, "Menu", &show_menu);
            _ = nk.bar.progress(ctx, &tkStatePopup.prog, 100, true);
            _ = nk.slider.int(ctx, 0, &tkStatePopup.slider, 16, 1);
            if (nk.contextual.itemLabel(ctx, "About", nk.text.Align.mid_center))
                show_app_about = nk_true;
            nk.selectable.label(ctx, if (tkStatePopup.select[0]) "Unselect" else "Select", NK_TEXT_LEFT, &tkStatePopup.select[0]);
            nk.selectable.label(ctx, if (tkStatePopup.select[1]) "Unselect" else "Select", NK_TEXT_LEFT, &tkStatePopup.select[1]);
            nk.selectable.label(ctx, if (tkStatePopup.select[2]) "Unselect" else "Select", NK_TEXT_LEFT, &tkStatePopup.select[2]);
            nk.selectable.label(ctx, if (tkStatePopup.select[3]) "Unselect" else "Select", NK_TEXT_LEFT, &tkStatePopup.select[3]);
        }

        // color contextual
        nk.layout.rowBegin(ctx, NK_STATIC, 30, 2);
        nk.layout.rowPush(ctx, 120);
        nk.text.label(ctx, "Right Click here:", NK_TEXT_LEFT);
        nk.layout.rowPush(ctx, 50);
        bounds = nk.widget.bounds(ctx);
        nk.button.color(ctx, color);
        nk.layout.rowEnd(ctx);

        if (nk.contextual.begin(ctx, 0, nk.vec2(350, 60), bounds)) {
            defer nk.contextual.end(ctx);
            nk.layout.rowDynamic(ctx, 30, 4);
            color.r = @truncate(u8, nk.property.i(ctx, "#r", 0, color.r, 255, 1, 1));
            color.g = @truncate(u8, nk.property.i(ctx, "#g", 0, color.g, 255, 1, 1));
            color.b = @truncate(u8, nk.property.i(ctx, "#b", 0, color.b, 255, 1, 1));
            color.a = @truncate(u8, nk.property.i(ctx, "#a", 0, color.a, 255, 1, 1));
        }

        // popup
        nk.layout.rowBegin(ctx, NK_STATIC, 30, 2);
        nk.layout.rowPush(ctx, 120);
        nk.text.label(ctx, "Popup:", NK_TEXT_LEFT);
        nk.layout.rowPush(ctx, 50);
        if (nk.button.label(ctx, "Popup")) {
            popup_active = 1;
        }
        nk.layout.rowEnd(ctx);

        if (popup_active) {
            if (nk.popup.begin(ctx, NK_POPUP_STATIC, "Error", 0, tkStatePopup.popup_s)) {
                defer nk.popup.end(ctx);
                nk.layout.rowDynamic(ctx, 25, 1);
                nk.text.label(ctx, "A terrible error as occured", NK_TEXT_LEFT);
                nk.layout.rowDynamic(ctx, 25, 2);
                if (nk.button.label(ctx, "OK")) {
                    popup_active = 0;
                    nk.popup.close(ctx);
                }
                if (nk.button.label(ctx, "Cancel")) {
                    popup_active = 0;
                    nk.popup.close(ctx);
                }
            } else popup_active = nk_false;
        }

        // tooltip
        nk.layout.rowStatic(ctx, 30, 150, 1);
        bounds = nk.widget.bounds(ctx);
        nk.text.label(ctx, "Hover me for tooltip", NK_TEXT_LEFT);
        if (nk.input.isMouseHoveringRect(in, bounds)) {
            nk_tooltip(ctx, "This is a tooltip");
        }
    }
}

const Chart_Type =
    enum(u32) { CHART_LINE = 0, CHART_HISTO = 1, CHART_MIXED = 2 };

const TkStateNoteBook = struct {
    current_tab: Chart_Type = CHART_LINE,
};

var tkStateNoteBook: TkStateNoteBook = .{};

fn tkNoteBook(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Notebook", NK_MINIMIZED)) {
        var bounds: nk.Rect = undefined;
        var step: f32 = (2 * 3.141592654) / 32;

        const names = [_][*c]u8{ "Lines", "Columns", "Mixed" };
        var id: f32 = 0;
        var i: i32 = 0;

        // Header
        nk.style.pushVec2(ctx, &ctx.style.window.spacing, nk.vec2(0, 0));
        nk.style.pushFloat(ctx, &ctx.style.button.rounding, 0);

        nk.layout.row_begin(ctx, NK_STATIC, 20, 3);
        i = 0;
        while (i < 3) : (i += 1) {
            // make sure button perfectly fits text
            const f: nk.Font = ctx.style.font;
            var text_width: f32 = f.width(f.userdata, f.height, names[i], nk_strlen(names[i]));
            var widget_width: f32 = text_width + 3 * ctx.style.button.padding.x;
            nk.layout.row_push(ctx, widget_width);
            if (@enumToInt(current_tab) == i) {
                // active tab gets highlighted
                const button_color: nk.StyleItem = ctx.style.button.normal;
                ctx.style.button.normal = ctx.style.button.active;
                current_tab = if (nk.button.label(ctx, names[i])) i else current_tab;
                ctx.style.button.normal = button_color;
            } else {
                current_tab = if (nk.button.label(ctx, names[i])) i else current_tab;
            }
        }
        nk.style.popFloat(ctx);

        // Body
        nk.layout.rowDynamic(ctx, 140, 1);
        if (nk.group.begin(ctx, "Notebook", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);

            nk.style.popVec2(ctx);
            switch (current_tab) {
                _ => {},

                CHART_LINE => {
                    nk.layout.rowDynamic(ctx, 100, 1);
                    bounds = nk.widget.bounds(ctx);
                    if (nk.chart.beginColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(255, 0, 0), nk.rest.nkRgb(150, 0, 0), 32, 0.0, 1.0)) {
                        defer nk.chart.end(ctx);

                        nk.chart.addSlotColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(0, 0, 255), nk.rest.nkRgb(0, 0, 150), 32, -1.0, 1.0);
                        i = 0;
                        id = 0;
                        while (i < 32) : (i += 1) {
                            nk.chartPushSlot(ctx, std.math.fabs(std.math.sin(id)), 0);
                            nk.chartPushSlot(ctx, std.math.cos(id), 1);
                            id += step;
                        }
                    }
                },
                CHART_HISTO => {
                    nk.layout.rowDynamic(ctx, 100, 1);
                    bounds = nk.widget.bounds(ctx);
                    if (nk.chart.beginColored(ctx, NK_CHART_COLUMN, nk.rest.nkRgb(255, 0, 0), nk.rest.nkRgb(150, 0, 0), 32, 0.0, 1.0)) {
                        defer nk.chart.end(ctx);
                        i = 0;
                        id = 0;
                        while (i < 32) : (i += 1) {
                            nk.chart.pushSlot(ctx, std.math.fabs(std.math.sin(id)), 0);
                            id += step;
                        }
                    }
                },
                CHART_MIXED => {
                    nk.layout.rowDynamic(ctx, 100, 1);
                    bounds = nk.widget.bounds(ctx);
                    if (nk.chart.beginColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(255, 0, 0), nk.rest.nkRgb(150, 0, 0), 32, 0.0, 1.0)) {
                        defer nk.chart.end(ctx);
                        nk.chart.addSlotColored(ctx, NK_CHART_LINES, nk.rest.nkRgb(0, 0, 255), nk.rest.nkRgb(0, 0, 150), 32, -1.0, 1.0);
                        nk.chart.addSlotColored(ctx, NK_CHART_COLUMN, nk.rest.nkRgb(0, 255, 0), nk.rest.nkRgb(0, 150, 0), 32, 0.0, 1.0);
                        i = 0;
                        id = 0;

                        while (i < 32) : (i += 1) {
                            nk.chart.pushSlot(ctx, std.math.fabs(std.math.sin(id)), 0);
                            nk.chart.pushSlot(ctx, std.math.fabs(std.math.cos(id)), 1);
                            nk.chart.pushSlot(ctx, std.math.fabs(std.math.sin(id)), 2);
                            id += step;
                        }
                    }
                },
            }
        } else nk.style.popVec2(ctx);
        nk.tree.pop(ctx);
    }
}

const TkStateGroup = struct {
    group_titlebar: bool = false,
    group_border: bool = true,
    group_no_scrollbar: bool = false,
    group_width: u32 = 320,
    group_height: u32 = 200,

    selected: [16]bool = undefined,
};

var tkStateGroup: TkStateGroup = .{};

fn tkGroup(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Group", NK_MINIMIZED)) {
        var group_flags: nk.Flags = 0;
        if (tkStateGroup.group_border) group_flags |= NK_WINDOW_BORDER;
        if (tkStateGroup.group_no_scrollbar) group_flags |= NK_WINDOW_NO_SCROLLBAR;
        if (tkStateGroup.group_titlebar) group_flags |= NK_WINDOW_TITLE;

        nk.layout.rowDynamic(ctx, 30, 3);
        nk.checkbox.label(ctx, "Titlebar", &tkStateGroup.group_titlebar);
        nk.checkbox.label(ctx, "Border", &tkStateGroup.group_border);
        nk.checkbox.label(ctx, "No Scrollbar", &tkStateGroup.group_no_scrollbar);

        nk.layout.row_begin(ctx, NK_STATIC, 22, 3);
        nk.layout.row_push(ctx, 50);
        nk.text.label(ctx, "size:", NK_TEXT_LEFT);
        nk.layout.row_push(ctx, 130);
        nk.property.int(ctx, "#Width:", 100, &tkStateGroup.group_width, 500, 10, 1);
        nk.layout.row_push(ctx, 130);
        nk.property.int(ctx, "#Height:", 100, &tkStateGroup.group_height, 500, 10, 1);
        nk.layout.row_end(ctx);

        nk.layout.rowStatic(ctx, @intToFloat(f32, tkStateGroup.group_height), tkStateGroup.group_width, 2);
        if (nk.group.begin(ctx, "Group", group_flags)) {
            var i = 0;

            nk.layout.rowStatic(ctx, 18, 100, 1);
            i = 0;
            while (i < 16) : (i += 1) {
                nk.selectable.label(ctx, if (tkStateGroup.selected[i]) "Selected" else "Unselected", NK_TEXT_CENTERED, &tkStateGroup.selected[i]);
            }
            nk.group.end(ctx);
        }
        nk.tree.pop(ctx);
    }
}

const TkStateTree = struct {
    root_selected: usize = 0,
    selected: [8]usize = undefined,
    sel_nodes: [4]usize = undefined,
};

var tkStateTree: TkStateTree = .{};

fn tkTree(cttx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Tree", NK_MINIMIZED)) {
        var sel = root_selected;
        if (nk_tree_element_push(ctx, NK_TREE_NODE, "Root", NK_MINIMIZED, &sel)) {
            var i = 0;
            var node_select = selected[0];
            if (sel != root_selected) {
                root_selected = sel;
                i = 0;
                while (i < 8) : (i += 1) {
                    selected[i] = sel;
                }
            }
            if (nk_tree_element_push(ctx, NK_TREE_NODE, "Node", NK_MINIMIZED, &node_select)) {
                var j = 0;
                if (node_select != selected[0]) {
                    selected[0] = node_select;
                    i = 0;
                    while (i < 4) : (i += 1) {
                        sel_nodes[i] = node_select;
                    }
                }
                nk.layout.rowStatic(ctx, 18, 100, 1);
                j = 0;
                while (j < 4) : (j += 1) {
                    nk_selectable_symbol_label(ctx, NK_SYMBOL_CIRCLE_SOLID, if (sel_nodes[j]) "Selected" else "Unselected", NK_TEXT_RIGHT, &sel_nodes[j]);
                }
                nk_tree_element_pop(ctx);
            }
            nk.layout.rowStatic(ctx, 18, 100, 1);
            i = 1;
            while (i < 8) : (i += 1) {
                nk_selectable_symbol_label(ctx, NK_SYMBOL_CIRCLE_SOLID, if (selected[i]) "Selected" else "Unselected", NK_TEXT_RIGHT, &selected[i]);
            }
            nk_tree_element_pop(ctx);
        }
        nk.tree.pop(ctx);
    }
}

const TkStateComplex = struct {
    groupleft_selected: [32]u32,
    groupright_selected: [4]u32,

    grouprightc_selected: [4]u32,
    grouprightb_selected: [4]u32,
};
var tkStateComplex: TkStateComplex = .{};

fn tkComplex(ctx: *nk.Context) void {
    if (nk.tree.push(ctx, NK_TREE_NODE, "Complex", NK_MINIMIZED)) {
        var i: i32 = 0;
        nk.layout.spaceBegin(ctx, NK_STATIC, 500, 64);
        nk.layout.spacePush(ctx, nk_rect(0, 0, 150, 500));
        if (nk.group.begin(ctx, "Group_left", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);
            nk.layout.rowStatic(ctx, 18, 100, 1);
            i = 0;
            while (i < 32) {
                nk.selectable.label(ctx, if (groupleft_selected[i]) "Selected" else "Unselected", NK_TEXT_CENTERED, &groupleft_selected[i]);
                i += 1;
            }
        }

        nk.layout.spacePush(ctx, nk_rect(160, 0, 150, 240));
        if (nk.group.begin(ctx, "Group_top", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);
            nk.layout.rowDynamic(ctx, 25, 1);
            nk.button.label(ctx, "#FFAA");
            nk.button.label(ctx, "#FFBB");
            nk.button.label(ctx, "#FFCC");
            nk.button.label(ctx, "#FFDD");
            nk.button.label(ctx, "#FFEE");
            nk.button.label(ctx, "#FFFF");
        }

        nk.layout.spacePush(ctx, nk_rect(160, 250, 150, 250));
        if (nk.group.begin(ctx, "Group_buttom", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);
            nk.layout.rowDynamic(ctx, 25, 1);
            nk.button.label(ctx, "#FFAA");
            nk.button.label(ctx, "#FFBB");
            nk.button.label(ctx, "#FFCC");
            nk.button.label(ctx, "#FFDD");
            nk.button.label(ctx, "#FFEE");
            nk.button.label(ctx, "#FFFF");
        }

        nk.layout.spacePush(ctx, nk_rect(320, 0, 150, 150));
        if (nk.group.begin(ctx, "Group_right_top", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);

            nk.layout.rowStatic(ctx, 18, 100, 1);
            i = 0;
            while (i < 4) : (i += 1) {
                nk.selectable.label(ctx, if (groupright_selected[i]) "Selected" else "Unselected", NK_TEXT_CENTERED, &groupright_selected[i]);
            }
        }

        nk.layout.spacePush(ctx, nk_rect(320, 160, 150, 150));
        if (nk.group.begin(ctx, "Group_right_center", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);

            nk.layout.rowStatic(ctx, 18, 100, 1);
            while (i < 4) : (i += 1) {
                nk.selectable.label(ctx, if (grouprightc_selected[i]) "Selected" else "Unselected", NK_TEXT_CENTERED, &grouprightc_selected[i]);
            }
        }

        nk.layout.spacePush(ctx, nk_rect(320, 320, 150, 150));
        if (nk.group.begin(ctx, "Group_right_bottom", NK_WINDOW_BORDER)) {
            defer nk.group.end(ctx);

            nk.layout.rowStatic(ctx, 18, 100, 1);

            i = 0;
            while (i < 4) : (i += 1) {
                nk.selectable.label(ctx, if (grouprightb_selected[i]) "Selected" else "Unselected", NK_TEXT_CENTERED, &grouprightb_selected[i]);
            }
        }
        nk.layout.spaceEnd(ctx);
        nk.tree.pop(ctx);
    }
}

pub fn overview(ctx: *nk.Context) !bool {

    // popups
    // window flags
    // window_flags = 0;

    // ctx.style.window.header.align = .NK_HEADER_RIGHT;
    const WINID = opaque {};
    if (nk.window.begin(ctx, WINID, nk.rect(10, 10, 400, 600), .{ .moveable = movable, .border = border, .scalable = resize, .title = "Overview" })) |win| {
        defer nk.window.end(ctx);

        if (show_menu) {
            menu(ctx);
        }

        if (show_app_about) {
            about(ctx);
        }

        // window flags
        if (nk.tree.push(ctx, opaque {}, .NK_TREE_TAB, "Window", .NK_MINIMIZED)) {
            nk.layout.rowDynamic(ctx, 30, 2);
            _ = nk.checkbox.label(ctx, "Titlebar", &titlebar);
            _ = nk.checkbox.label(ctx, "Menu", &show_menu);
            _ = nk.checkbox.label(ctx, "Border", &border);
            _ = nk.checkbox.label(ctx, "Resizable", &resize);
            _ = nk.checkbox.label(ctx, "Movable", &movable);
            _ = nk.checkbox.label(ctx, "No Scrollbar", &no_scrollbar);
            _ = nk.checkbox.label(ctx, "Minimizable", &minimizable);
            _ = nk.checkbox.label(ctx, "Scale Left", &scale_left);
            nk.tree.pop(ctx);
        }

        tkWidgets(ctx);

        tkCharts(ctx);

        tkPopup(ctx);

        if (nk.tree.push(ctx, opaque {}, .NK_TREE_TAB, "Layout", .NK_MINIMIZED)) {
            if (nk.tree.push(ctx, opaque {}, .NK_TREE_NODE, "Widget", .NK_MINIMIZED)) {
                defer nk.tree.pop(ctx);
                const ratio_two = [_]f32{ 0.2, 0.6, 0.2 };
                const width_two = [_]f32{ 100, 200, 50 };

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Dynamic fixed column layout with generated position and size:", nk.text.Align.mid_left);
                nk.layout.rowDynamic(ctx, 30, 3);
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "static fixed column layout with generated position and size:", nk.text.Align.mid_left);
                nk.layout.rowStatic(ctx, 30, 100, 3);
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Dynamic array-based custom column layout with generated position and custom size:", nk.text.Align.mid_left);
                nk.layout.row(ctx, .NK_DYNAMIC, 30.0, ratio_two[0..ratio_two.len]);
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Static array-based custom column layout with generated position and custom size:", nk.text.Align.mid_left);
                nk.layout.row(ctx, .NK_STATIC, 30.0, width_two[0..width_two.len]);
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Dynamic immediate mode custom column layout with generated position and custom size:", nk.text.Align.mid_left);
                nk.layout.rowBegin(ctx, .NK_DYNAMIC, 30, 3);
                nk.layout.rowPush(ctx, 0.2);
                _ = nk.button.label(ctx, "button");
                nk.layout.rowPush(ctx, 0.6);
                _ = nk.button.label(ctx, "button");
                nk.layout.rowPush(ctx, 0.2);
                _ = nk.button.label(ctx, "button");
                nk.layout.rowEnd(ctx);

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Static immediate mode custom column layout with generated position and custom size:", nk.text.Align.mid_left);
                nk.layout.rowBegin(ctx, .NK_STATIC, 30, 3);
                nk.layout.rowPush(ctx, 100);
                _ = nk.button.label(ctx, "button");
                nk.layout.rowPush(ctx, 200);
                _ = nk.button.label(ctx, "button");
                nk.layout.rowPush(ctx, 50);
                _ = nk.button.label(ctx, "button");
                nk.layout.rowEnd(ctx);

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Static free space with custom position and custom size:", nk.text.Align.mid_left);
                nk.layout.spaceBegin(ctx, .NK_STATIC, 60, 4);
                nk.layout.spacePush(ctx, nk.rect(100, 0, 100, 30));
                _ = nk.button.label(ctx, "button");
                nk.layout.spacePush(ctx, nk.rect(0, 15, 100, 30));
                _ = nk.button.label(ctx, "button");
                nk.layout.spacePush(ctx, nk.rect(200, 15, 100, 30));
                _ = nk.button.label(ctx, "button");
                nk.layout.spacePush(ctx, nk.rect(100, 30, 100, 30));
                _ = nk.button.label(ctx, "button");
                nk.layout.spaceEnd(ctx);

                nk.layout.rowDynamic(ctx, 30, 1);
                nk.text.label(ctx, "Row template:", nk.text.Align.mid_left);
                nk.layout.rowTemplateBegin(ctx, 30);
                nk.layout.rowTemplatePushDynamic(ctx);
                nk.layout.rowTemplatePushVariable(ctx, 80);
                nk.layout.rowTemplatePushStatic(ctx, 80);
                nk.layout.rowTemplateEnd(ctx);
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");
                _ = nk.button.label(ctx, "button");
            }

            // tkGroup(ctx);

            // tkTree(ctx);
            // tkNoteBook(ctx);

            // if (nk.tree.push(ctx, NK_TREE_NODE, "Simple", NK_MINIMIZED)) {
            //     defer nk.tree.pop(ctx);
            //     nk.layout.rowDynamic(ctx, 300, 2);
            //     if (nk.group.begin(ctx, "Group_Without_Border", 0)) {
            //         defer nk.group.end(ctx);
            //         var i = 0;
            //         var buffer: [64]u8 = undefined;
            //         nk.layout.rowStatic(ctx, 18, 150, 1);
            //         while (i < 64) : (i += 1) {
            //             sprintf(buffer, "0x%02x", i);
            //             nk.text.labelf(ctx, NK_TEXT_LEFT, "%s: scrollable region", buffer);
            //         }
            //     }
            //     if (nk.group.begin(ctx, "Group_With_Border", NK_WINDOW_BORDER)) {
            //         defer nk.group.end(ctx);
            //         var i = 0;
            //         var buffer: [64]u8 = undefined;
            //         nk.layout.rowDynamic(ctx, 25, 2);
            //         while (i < 64) : (i += 1) {
            //             const n = (((@mod(i, 7) * 10) ^ 32)) + (64 + @mod(i, 2) * 2);
            //             sprintf(buffer, "%08d", n);
            //             nk.button.label(ctx, buffer);
            //         }
            //     }
            // }

            // tkComplex(ctx);
            // tkSplitter(ctx);
        }
    }

    return !nk.window.isClosed(ctx, WINID);
}
