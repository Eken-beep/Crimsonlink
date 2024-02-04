const std = @import("std");
const rl = @import("raylib");

// TODO automate the generation of this abomination
pub const all_images = [_][:0]const u8{
    "assets/betamap2.png",
    "assets/player/MainCharacter1.png",
    "assets/player/MainCharacter2.png",
    "assets/player/MainCharacter3.png",
    "assets/player/MainCharacter4.png",
    "assets/enemy1.png",
    "assets/enemy2.png",
};

pub fn loadImages(allocator: std.mem.Allocator, images: [all_images.len][:0]const u8) ![]rl.Image {
    var result: []rl.Image = try allocator.alloc(rl.Image, images.len);
    for (images, 0..) |image, i| {
        result[i] = rl.loadImage(image);
    }
    return result;
}

pub fn Animation(comptime T: type) type {
    return struct {
        const _self = @This();
        frames: []rl.Texture2D,
        // This tells us what frame to draw, from the slice
        frame: T,
        // This is the time inbetween frames in the animation
        frametime: f32,
        counter: f32,
        active: bool,
        pub fn step(self: *_self, dt: f32) *rl.Texture2D {
            self.counter += dt;
            if (!self.active) {
                self.frame = 0;
                return &self.frames[0];
            }
            if (self.counter > self.frametime) {
                // Overflow the variable to begin counting at zero again
                self.frame +%= 1;
                self.counter = 0;
            }
            return &self.frames[self.frame];
        }
        pub fn init(frametime: f32, textures: []rl.Texture2D) Animation(T) {
            return Animation(T){ .frametime = frametime, .frames = textures, .frame = 0, .counter = 0, .active = true };
        }
    };
}
