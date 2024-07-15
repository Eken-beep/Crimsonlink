const std = @import("std");
const rl = @import("raylib");

const Self = @This();

// The ammount we scale each pixle no matter the window size
pub const PXSCALE = 4;
pub const WALLSIZE = 18 * PXSCALE;

width: u16,
height: u16,
scale: f32,
gui_scale: u8 = 1,
fontsize: u16 = 28,
// Pixles we try to space the gui elements with
gui_spacing: u16 = 18,
origin: @Vector(2, f32),

pub fn update(self: *Self, w: u16, h: u16, preferred_width: u16, preferred_height: u16) void {
    self.width = w;
    self.height = h;
    self.scale = @min(@as(f32, @floatFromInt(w)) / 1600, @as(f32, @floatFromInt(h)) / 900);

    const spw: f32 = self.scale * @as(f32, @floatFromInt(preferred_width));
    const sph: f32 = self.scale * @as(f32, @floatFromInt(preferred_height));
    self.origin = @Vector(2, f32){
        @divTrunc(@as(f32, @floatFromInt(w)) - spw, 2),
        @divTrunc(@as(f32, @floatFromInt(h)) - sph, 2),
    };
}
