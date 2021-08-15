// root definition for all backends
// this define the backend abstraction to be able to change it depending on
// the plateform

const nk = @import("zig-nuklear");

pub fn createBackEnd(comptime backEndType: type, comptime wintype: type) anyerror!type {
    return struct {
        const Self = @This();

        backend: *backEndType,
        win: *wintype,

        // // image part
        _loadImage: *const fn (self: *backEndType, file: [*c]const u8) anyerror!nk.Image = undefined,
        _freeImage: *const fn (self: *backEndType, image: nk.Image) anyerror!void = undefined,

        // // windows management
        _createWindow: *const fn (w: u32, h: u32) anyerror!*wintype = undefined,

        // // events handling
        _handleAllCurrentEvents: *const fn (self: *backEndType, ctx: *nk.Context, win: *wintype) anyerror!bool = undefined,

        // // rendering
        _render: *const fn (self: *backEndType, ctx: *nk.Context, win: *wintype) anyerror!void = undefined,

        pub fn wrap(self: *Self, backend: *backEndType, win: *wintype) !void {
            self.backend = backend;
            self.win = win;
        }

        // Create a window usign the native toolkit
        pub fn createWindow(self: *Self, w: u32, h: u32) Win {
            const innerWin = self._createWindow.*(self.backend, w, h);
            return .{ .innerWin = innerWin };
        }

        pub fn loadImage(self: *Self, file: [*c]const u8) anyerror!nk.Image {
            return self._loadImage.*(self.backend, file);
        }

        pub fn freeImage(self: *Self, image: nk.Image) anyerror!void {
            try self._loadImage.*(self.backend, image);
        }

        // render the gui
        pub fn render(self: *Self, ctx: *nk.Context) !void {
            return try self._render.*(self.backend, ctx, self.win);
        }

        // handle all current events
        pub fn handleAllCurrentEvents(self: *Self, ctx: *nk.Context) anyerror!bool {
            return try self._handleAllCurrentEvents.*(self.backend, ctx, self.win);
        }
    };
}
