const std = @import("std");
const rl = @import("raylib");

pub fn Animation(comptime T: type) type {
    return struct {
        frames: []rl.Texture2D,
        // This tells us what frame to draw, from the slice
        frame: T = 0,
        // This is the time inbetween frames in the animation
        frametime: f32,
        counter: f32 = 0,
        fn step(self: *Animation(T), dt: f32) *rl.Texture2D {
            self.counter += dt;
            if (self.counter > self.frametime) {
                self.frame +%= 1;
                self.counter = 0;
            }
            return &self.frames[self.frame];
        }
        fn init(frametime: f32, textures: []rl.Texture2D) Animation(T) {
            return Animation(T){ .frametime = frametime, .textures = textures };
        }
    };
}
