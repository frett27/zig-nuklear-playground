const nk = @import("zig-nuklear");

pub const Theme = enum { THEME_BLACK, THEME_WHITE, THEME_RED, THEME_BLUE, THEME_DARK , THEME_DEFAULT};

pub fn setStyle(ctx: *nk.Context, theme: Theme) void {
    var table : [nk.color_count]nk.Color = undefined;
    for(table) | c, index| {
        table[index] = nk.rest.nkRgba(0, 0, 0, 0);
    }

    switch (theme) {
        .THEME_WHITE => {
            
            table[@enumToInt(nk.StyleColors.NK_COLOR_TEXT)] = nk.rest.nkRgba(70, 70, 70, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_WINDOW)] = nk.rest.nkRgba(175, 175, 175, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_HEADER)] = nk.rest.nkRgba(175, 175, 175, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BORDER)] = nk.rest.nkRgba(0, 0, 0, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON)] = nk.rest.nkRgba(185, 185, 185, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_HOVER)] = nk.rest.nkRgba(170, 170, 170, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_ACTIVE)] = nk.rest.nkRgba(160, 160, 160, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE)] = nk.rest.nkRgba(150, 150, 150, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_HOVER)] = nk.rest.nkRgba(120, 120, 120, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_CURSOR)] = nk.rest.nkRgba(175, 175, 175, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT)] = nk.rest.nkRgba(190, 190, 190, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT_ACTIVE)] = nk.rest.nkRgba(175, 175, 175, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER)] = nk.rest.nkRgba(190, 190, 190, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR)] = nk.rest.nkRgba(80, 80, 80, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_HOVER)] = nk.rest.nkRgba(70, 70, 70, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_ACTIVE)] = nk.rest.nkRgba(60, 60, 60, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_PROPERTY)] = nk.rest.nkRgba(175, 175, 175, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT)] = nk.rest.nkRgba(150, 150, 150, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT_CURSOR)] = nk.rest.nkRgba(0, 0, 0, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_COMBO)] = nk.rest.nkRgba(175, 175, 175, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART)] = nk.rest.nkRgba(160, 160, 160, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR)] = nk.rest.nkRgba(45, 45, 45, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR_HIGHLIGHT)] = nk.rest.nkRgba(255, 0, 0, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR)] = nk.rest.nkRgba(180, 180, 180, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR)] = nk.rest.nkRgba(140, 140, 140, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_HOVER)] = nk.rest.nkRgba(150, 150, 150, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_ACTIVE)] = nk.rest.nkRgba(160, 160, 160, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TAB_HEADER)] = nk.rest.nkRgba(180, 180, 180, 255);
            nk.style.fromTable(ctx, &table);
        },

        .THEME_RED => {
            table[@enumToInt(nk.StyleColors.NK_COLOR_TEXT)] = nk.rest.nkRgba(190, 190, 190, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_WINDOW)] = nk.rest.nkRgba(30, 33, 40, 215);
            table[@enumToInt(nk.StyleColors.NK_COLOR_HEADER)] = nk.rest.nkRgba(181, 45, 69, 220);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BORDER)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON)] = nk.rest.nkRgba(181, 45, 69, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_HOVER)] = nk.rest.nkRgba(190, 50, 70, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_ACTIVE)] = nk.rest.nkRgba(195, 55, 75, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_HOVER)] = nk.rest.nkRgba(45, 60, 60, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_CURSOR)] = nk.rest.nkRgba(181, 45, 69, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT_ACTIVE)] = nk.rest.nkRgba(181, 45, 69, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR)] = nk.rest.nkRgba(181, 45, 69, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_HOVER)] = nk.rest.nkRgba(186, 50, 74, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_ACTIVE)] = nk.rest.nkRgba(191, 55, 79, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_PROPERTY)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT)] = nk.rest.nkRgba(51, 55, 67, 225);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT_CURSOR)] = nk.rest.nkRgba(190, 190, 190, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_COMBO)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART)] = nk.rest.nkRgba(51, 55, 67, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR)] = nk.rest.nkRgba(170, 40, 60, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR_HIGHLIGHT)] = nk.rest.nkRgba(255, 0, 0, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR)] = nk.rest.nkRgba(30, 33, 40, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR)] = nk.rest.nkRgba(64, 84, 95, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_HOVER)] = nk.rest.nkRgba(70, 90, 100, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_ACTIVE)] = nk.rest.nkRgba(75, 95, 105, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TAB_HEADER)] = nk.rest.nkRgba(181, 45, 69, 220);
            nk.style.fromTable(ctx, &table);
        },

        .THEME_BLUE => {
            table[@enumToInt(nk.StyleColors.NK_COLOR_TEXT)] = nk.rest.nkRgba(20, 20, 20, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_WINDOW)] = nk.rest.nkRgba(202, 212, 214, 215);
            table[@enumToInt(nk.StyleColors.NK_COLOR_HEADER)] = nk.rest.nkRgba(137, 182, 224, 220);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BORDER)] = nk.rest.nkRgba(140, 159, 173, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON)] = nk.rest.nkRgba(137, 182, 224, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_HOVER)] = nk.rest.nkRgba(142, 187, 229, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_ACTIVE)] = nk.rest.nkRgba(147, 192, 234, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE)] = nk.rest.nkRgba(177, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_HOVER)] = nk.rest.nkRgba(182, 215, 215, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_CURSOR)] = nk.rest.nkRgba(137, 182, 224, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT)] = nk.rest.nkRgba(177, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT_ACTIVE)] = nk.rest.nkRgba(137, 182, 224, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER)] = nk.rest.nkRgba(177, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR)] = nk.rest.nkRgba(137, 182, 224, 245);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_HOVER)] = nk.rest.nkRgba(142, 188, 229, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_ACTIVE)] = nk.rest.nkRgba(147, 193, 234, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_PROPERTY)] = nk.rest.nkRgba(210, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT)] = nk.rest.nkRgba(210, 210, 210, 225);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT_CURSOR)] = nk.rest.nkRgba(20, 20, 20, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_COMBO)] = nk.rest.nkRgba(210, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART)] = nk.rest.nkRgba(210, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR)] = nk.rest.nkRgba(137, 182, 224, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR_HIGHLIGHT)] = nk.rest.nkRgba(255, 0, 0, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR)] = nk.rest.nkRgba(190, 200, 200, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR)] = nk.rest.nkRgba(64, 84, 95, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_HOVER)] = nk.rest.nkRgba(70, 90, 100, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_ACTIVE)] = nk.rest.nkRgba(75, 95, 105, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TAB_HEADER)] = nk.rest.nkRgba(156, 193, 220, 255);
            nk.style.fromTable(ctx, &table);
        },
        .THEME_DARK => {
            table[@enumToInt(nk.StyleColors.NK_COLOR_TEXT)] = nk.rest.nkRgba(210, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_WINDOW)] = nk.rest.nkRgba(57, 67, 71, 215);
            table[@enumToInt(nk.StyleColors.NK_COLOR_HEADER)] = nk.rest.nkRgba(51, 51, 56, 220);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BORDER)] = nk.rest.nkRgba(46, 46, 46, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON)] = nk.rest.nkRgba(48, 83, 111, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_HOVER)] = nk.rest.nkRgba(58, 93, 121, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_BUTTON_ACTIVE)] = nk.rest.nkRgba(63, 98, 126, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE)] = nk.rest.nkRgba(50, 58, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_HOVER)] = nk.rest.nkRgba(45, 53, 56, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TOGGLE_CURSOR)] = nk.rest.nkRgba(48, 83, 111, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT)] = nk.rest.nkRgba(57, 67, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SELECT_ACTIVE)] = nk.rest.nkRgba(48, 83, 111, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER)] = nk.rest.nkRgba(50, 58, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR)] = nk.rest.nkRgba(48, 83, 111, 245);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_HOVER)] = nk.rest.nkRgba(53, 88, 116, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SLIDER_CURSOR_ACTIVE)] = nk.rest.nkRgba(58, 93, 121, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_PROPERTY)] = nk.rest.nkRgba(50, 58, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT)] = nk.rest.nkRgba(50, 58, 61, 225);
            table[@enumToInt(nk.StyleColors.NK_COLOR_EDIT_CURSOR)] = nk.rest.nkRgba(210, 210, 210, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_COMBO)] = nk.rest.nkRgba(50, 58, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART)] = nk.rest.nkRgba(50, 58, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR)] = nk.rest.nkRgba(48, 83, 111, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_CHART_COLOR_HIGHLIGHT)] = nk.rest.nkRgba(255, 0, 0, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR)] = nk.rest.nkRgba(50, 58, 61, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR)] = nk.rest.nkRgba(48, 83, 111, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_HOVER)] = nk.rest.nkRgba(53, 88, 116, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_SCROLLBAR_CURSOR_ACTIVE)] = nk.rest.nkRgba(58, 93, 121, 255);
            table[@enumToInt(nk.StyleColors.NK_COLOR_TAB_HEADER)] = nk.rest.nkRgba(48, 83, 111, 255);
            nk.style.fromTable(ctx, &table);
        },
        .THEME_DEFAULT, .THEME_BLACK => {
            nk.style.default(ctx);
        },
    }
}


test {
    std.testing.refAllDecls(@This());
}