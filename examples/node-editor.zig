//  nuklear - v1.00 - public domain
//  This is a simple node editor just to show a simple implementation and that
//   it is possible to achieve it with this library. While all nodes inside this
//   example use a simple color modifier as content you could change them
//   to have your custom content depending on the node time.
//   Biggest difference to most usual implementation is that this example does
//   not have connectors on the right position of the property that it links.
//   This is mainly done out of laziness and could be implemented as well but
//   requires calculating the position of all rows and add connectors.
//   In addition adding and removing nodes is quite limited at the
//   moment since it is based on a simple fixed array. If this is to be converted
//   into something more serious it is probably best to extend it.

// this file is a zig translation of nuklear node editor for zig

const nk = @import("zig-nuklear");
const std = @import("std");

const NodeLinking = struct {
    active: bool,
    node: ?*Node,
    input_id: u32,
    input_slot: u32,
};
const Node = struct {
    ID: u32,
    name: [32]u8,
    bounds: nk.Rect,
    value: f32,
    color: nk.Color,
    input_count: usize,
    output_count: usize,
    next: ?*Node,
    prev: ?*Node,
};

const NodeLink = struct {
    input_id: u32,
    input_slot: u32,
    output_id: u32,
    output_slot: u32,
    in: nk.Vec2,
    out: nk.Vec2,
};

const NodeEditor = struct {
    initialized: bool,
    node_buf: [32]Node,
    links: [64]NodeLink,
    begin: ?*Node,
    end: ?*Node,
    node_count: usize,
    link_count: usize,
    bounds: nk.Rect,
    selected: ?*Node,
    show_grid: usize,
    scrolling: nk.Vec2,
    linking: NodeLinking,
};

var nodeEditor: NodeEditor = undefined;

fn nodeEditorPush(editor: *NodeEditor, node: *Node) !void {
    if (editor.begin == null) {
        node.next = null;
        node.prev = null;
        editor.begin = node;
        editor.end = node;
    } else {
        node.prev = editor.end;
        if (editor.end) |e| {
            e.next = node;
        }
        node.next = null;
        editor.end = node;
    }
}

fn nodeEditorPop(editor: *NodeEditor, node: *Node) !void {
    if (node.next) |n|
        n.prev = node.prev;
    if (node.prev) |p|
        p.next = node.next;
    if (editor.end == node)
        editor.end = node.prev;
    if (editor.begin == node)
        editor.begin = node.next;
    node.next = null;
    node.prev = null;
}

fn nodeEditorFind(editor: *NodeEditor, ID: u32) !?*Node {
    var iter: ?*Node = editor.begin;
    while (iter) |it| {
        if (it.ID == ID)
            return it;
        iter = it.next;
    }
    return null;
}

var IDs: u32 = 0;

fn nodeEditorAdd(editor: *NodeEditor, name: [*:0]const u8, bounds: nk.Rect, col: nk.Color, in_count: usize, out_count: usize) !void {
    var node: *Node = undefined;
    std.debug.assert(editor.node_count < editor.node_buf.len);
    editor.node_count += 1;
    node = &editor.node_buf[editor.node_count - 1];
    node.ID = IDs;
    IDs += 1;
    node.value = 0;
    node.color = nk.rest.nkRgb(255, 0, 0);
    node.input_count = in_count;
    node.output_count = out_count;
    node.color = col;
    node.bounds = bounds;

    node.name = name[0..32].*;

    try nodeEditorPush(editor, node);
}

fn nodeEditorLink(editor: *NodeEditor, in_id: u32, in_slot: u32, out_id: u32, out_slot: u32) !void {
    var link: *NodeLink = undefined;
    std.debug.assert(editor.link_count + 1 < editor.links.len);
    editor.link_count += 1;
    link = &editor.links[editor.link_count - 1];
    link.input_id = in_id;
    link.input_slot = in_slot;
    link.output_id = out_id;
    link.output_slot = out_slot;
}

fn nodeEditorInit(editor: *NodeEditor) !void {
    editor.* = std.mem.zeroes(NodeEditor);
    editor.begin = null;
    editor.end = null;
    try nodeEditorAdd(editor, "Source", nk.rect(40, 10, 180, 220), nk.rest.nkRgb(255, 0, 0), 0, 1);
    try nodeEditorAdd(editor, "Source", nk.rect(40, 260, 180, 220), nk.rest.nkRgb(0, 255, 0), 0, 1);
    try nodeEditorAdd(editor, "Combine", nk.rect(400, 100, 180, 220), nk.rest.nkRgb(0, 0, 255), 2, 2);
    try nodeEditorLink(editor, 0, 0, 2, 0);
    try nodeEditorLink(editor, 1, 0, 2, 1);
    editor.show_grid = 1;
}

pub fn nodeEditorMain(ctx: *nk.Context) !bool {
    var total_space: nk.Rect = undefined;
    var in: nk.Input = ctx.input;

    var canvas: *nk.CommandBuffer = undefined;

    var updated: ?*Node = null;

    var nodedit: *NodeEditor = &nodeEditor;

    if (!nodeEditor.initialized) {
        try nodeEditorInit(&nodeEditor);
        nodeEditor.initialized = true;
    }

    const WINID = opaque {};
    if (nk.window.begin(ctx, WINID, nk.rect(0, 0, 800, 600), .{ .border = true, .scrollbar = false, .moveable = true, .closable = true })) |nkwin| {
        defer nk.window.end(ctx);

        // allocate complete window space
        canvas = nk.window.getCanvas(ctx);
        total_space = nk.window.getContentRegion(ctx);
        nk.layout.spaceBegin(ctx, .NK_STATIC, total_space.h, nodedit.node_count);
        {
            defer nk.layout.spaceEnd(ctx);

            var size: nk.Rect = nk.layout.spaceBounds(ctx);
            var node: ?*nk.Panel = null;

            if (nodedit.show_grid > 0) {
                // display grid
                const grid_size: f32 = 32.0;
                const grid_color = nk.rest.nkRgb(50, 50, 50);

                var x: f32 = @mod(size.x - nodedit.scrolling.x, grid_size);
                while (x < size.w) {
                    nk.stroke.line(canvas, x + size.x, size.y, x + size.x, size.y + size.h, 1.0, grid_color);
                    x += grid_size;
                }

                var y: f32 = @mod(size.y - nodedit.scrolling.y, grid_size);
                while (y < size.h) {
                    nk.stroke.line(canvas, size.x, size.y + y, size.x + size.w, size.y + y, 1.0, grid_color);
                    y += grid_size;
                }
            }

            var it: ?*Node = nodedit.begin;

            while (it) |i| {

                // execute each node as a movable group
                // calculate scrolled node window position and size
                nk.layout.spacePush(ctx, nk.rect(i.bounds.x - nodedit.scrolling.x, 
                     i.bounds.y - nodedit.scrolling.y, i.bounds.w, i.bounds.h));

                // execute node window
                if (nk.group.beginTitled(ctx, i.name[0..32], .{ .moveable = true, .scrollbar = false, .border = true, .title = i.name[0..32] })) {
                    defer nk.group.end(ctx);
                    // always have last selected node on top

                    node = nk.window.getPanel(ctx);
                    if (node) |enode| {
                        if (nk.input.mouseClicked(&in, .NK_BUTTON_LEFT, enode.bounds) and
                            (!(i.prev != null and nk.input.mouseClicked(&in, .NK_BUTTON_LEFT, nk.layout.spaceRectToScreen(ctx, enode.bounds)))) and
                            nodedit.end != i)
                        {
                            updated = i;
                        }
                    }

                    // ================= NODE CONTENT =====================*/
                    nk.layout.rowDynamic(ctx, 25, 1);
                    _ = nk.button.color(ctx, i.color);
                    i.color.r = @intCast(u8, nk.property.i(ctx, "#R:", 0, i.color.r, 255, 1, 1));
                    i.color.g = @intCast(u8, nk.property.i(ctx, "#G:", 0, i.color.g, 255, 1, 1));
                    i.color.b = @intCast(u8, nk.property.i(ctx, "#B:", 0, i.color.b, 255, 1, 1));
                    i.color.a = @intCast(u8, nk.property.i(ctx, "#A:", 0, i.color.a, 255, 1, 1));
                    // ====================================================*/

                }
                if (node) |enode| {
                    // node connector and linking
                    var space: f32 = 0;
                    var bounds: nk.Rect = undefined;
                    bounds = nk.layout.spaceRectToLocal(ctx, enode.bounds);
                    bounds.x += nodedit.scrolling.x;
                    bounds.y += nodedit.scrolling.y;
                    i.bounds = bounds;

                    // output connector
                    space = enode.bounds.h / @intToFloat(f32, ((i.output_count) + 1));
                    var n: u32 = 0;
                    while (n < i.output_count) {
                        var circle: nk.Rect = undefined;
                        circle.x = enode.bounds.x + enode.bounds.w - 4;
                        circle.y = enode.bounds.y + space * @intToFloat(f32, (n + 1));
                        circle.w = 8;
                        circle.h = 8;
                        nk.rest.nkFillCircle(canvas, circle, nk.rest.nkRgb(100, 100, 100));

                        // start linking process
                        if (nk.input.hasMouseClickDownInRect(&in, .NK_BUTTON_LEFT, circle, true)) {
                            nodedit.linking.active = true;
                            nodedit.linking.node = i;
                            nodedit.linking.input_id = i.ID;
                            nodedit.linking.input_slot = n;
                        }

                        // draw curve from linked node slot to mouse position
                        if (nodedit.linking.active and nodedit.linking.node == i and
                            nodedit.linking.input_slot == n)
                        {
                            var l0: nk.Vec2 = nk.vec2(circle.x + 3, circle.y + 3);
                            var l1: nk.Vec2 = in.mouse.pos;
                            nk.stroke.curve(canvas, l0.x, l0.y, l0.x + 50.0, l0.y, l1.x - 50.0, l1.y, l1.x, l1.y, 1.0, nk.rest.nkRgb(100, 100, 100));
                        }

                        n += 1;
                    }

                    // input connector
                    space = enode.bounds.h / @intToFloat(f32, ((i.input_count) + 1));
                    n = 0;
                    while (n < i.input_count) {
                        var circle: nk.Rect = undefined;
                        circle.x = enode.bounds.x - 4;
                        circle.y = enode.bounds.y + space * @intToFloat(f32, (n + 1));
                        circle.w = 8;
                        circle.h = 8;
                        nk.rest.nkFillCircle(canvas, circle, nk.rest.nkRgb(100, 100, 100));
                        if (nk.input.isMouseReleased(&in, .NK_BUTTON_LEFT) and
                            nk.input.isMouseHoveringRect(&in, circle) and
                            nodedit.linking.active and nodedit.linking.node != it)
                        {
                            nodedit.linking.active = false;
                            try nodeEditorLink(nodedit, nodedit.linking.input_id, nodedit.linking.input_slot, i.ID, n);
                        }
                        n += 1;
                    }
                }

                it = i.next;
            }

            // reset linking connection
            if (nodedit.linking.active and nk.input.isMouseReleased(&in, .NK_BUTTON_LEFT)) {
                nodedit.linking.active = false;
                nodedit.linking.node = null;
                std.debug.print("linking failed\n", .{});
            }

            //  draw each link
            var nl: usize = 0;
            while (nl < nodedit.link_count) {
                var link: *NodeLink = &nodedit.links[nl];
                var ni: ?*Node = try nodeEditorFind(nodedit, link.input_id);
                var no: ?*Node = try nodeEditorFind(nodedit, link.output_id);

                if (ni) |rni| {
                    if (no) |rno| {
                        if (node) |rnode| {
                            var spacei: f32 = rnode.bounds.h / @intToFloat(f32, ((rni.output_count) + 1));
                            var spaceo: f32 = rnode.bounds.h / @intToFloat(f32, ((rno.input_count) + 1));

                            var l0: nk.Vec2 = nk.layout.spaceToScreen(ctx, nk.vec2(rni.bounds.x + rni.bounds.w, 3.0 + rni.bounds.y + spacei * @intToFloat(f32, (link.input_slot + 1))));
                            var l1: nk.Vec2 = nk.layout.spaceToScreen(ctx, nk.vec2(rno.bounds.x, 3.0 + rno.bounds.y + spaceo * @intToFloat(f32, (link.output_slot + 1))));

                            l0.x -= nodedit.scrolling.x;
                            l0.y -= nodedit.scrolling.y;
                            l1.x -= nodedit.scrolling.x;
                            l1.y -= nodedit.scrolling.y;

                            nk.stroke.curve(canvas, l0.x, l0.y, l0.x + 50.0, l0.y, l1.x - 50.0, l1.y, l1.x, l1.y, 1.0, nk.rest.nkRgb(100, 100, 100));
                        }
                    } else {
                    std.debug.print("node {} not found\n", .{link.output_id});                        
                    }
                } else {
                    std.debug.print("no node {} not found \n", .{link.input_id});
                }
                nl += 1;
            }

            if (updated) |updatedNode| {
                // reshuffle nodes to have least recently selected node on top
                try nodeEditorPop(nodedit, updatedNode);
                try nodeEditorPush(nodedit, updatedNode);
            }

            // node selection
            if (nk.input.mouseClicked(&in, .NK_BUTTON_LEFT, nk.layout.spaceBounds(ctx))) {
                var it2 = nodedit.begin;
                nodedit.selected = null;
                nodedit.bounds = nk.rect(in.mouse.pos.x, in.mouse.pos.y, 100, 200);
                while (it2) |eit2| {
                    var b: nk.Rect = nk.layout.spaceRectToScreen(ctx, eit2.bounds);
                    b.x -= nodedit.scrolling.x;
                    b.y -= nodedit.scrolling.y;
                    if (nk.input.isMouseHoveringRect(&in, b))
                        nodedit.selected = eit2;
                    it2 = eit2.next;
                }
            }

            // contextual menu
            if (nk.contextual.begin(ctx, 0, nk.vec2(100, 220), nk.window.getBounds(ctx))) {
                defer nk.contextual.end(ctx);
                const grid_option = [_][*c]const u8{ "Show Grid", "Hide Grid" };

                nk.layout.rowDynamic(ctx, 25, 1);
                if (nk.contextual.itemLabel(ctx, "New", nk.text.Align.mid_center))
                    try nodeEditorAdd(nodedit, "New", nk.rect(400, 260, 180, 220), nk.rest.nkRgb(255, 255, 255), 1, 2);
                if (nk.contextual.itemLabel(ctx, grid_option[nodedit.show_grid][0..10], nk.text.Align.mid_center))
                    nodedit.show_grid = if (nodedit.show_grid == 0) 1 else 0;
            }
        }

        // window content scrolling
        if (nk.input.isMouseHoveringRect(&in, nk.window.getBounds(ctx)) and
            nk.input.isMouseDown(&in, .NK_BUTTON_MIDDLE))
        {
            nodedit.scrolling.x -= in.mouse.delta.x;
            nodedit.scrolling.y -= in.mouse.delta.y;
        }
    }

    return !nk.window.isClosed(ctx, WINID);
}

test {
    std.testing.refAllDecls(@This());
}
