const std = @import("std");
const rl = @import("raylib");

// change these to arrays
const images = [_][:0]const u8 {
    "assets/betamap1.png",
    "assets/betamap2.png",

    "assets/player/MainCharacter1.png",
    "assets/player/MainCharacter2.png",
    "assets/player/MainCharacter3.png",
    "assets/player/MainCharacter4.png",
};

const animation_bound = struct {
    s: u8,
    l: u8,
};
const sprite_names = .{
    .maps = animation_bound{ .s = 0, .l = 2 },
    .player = animation_bound{ .s = 2, .l = 4 },
};

pub fn loadTextures(allocator: std.mem.Allocator) ![]rl.Texture2D {
    var image_buffer = try allocator.alloc(rl.Image, images.len);
    for (images, 0..) |image, i| {
        image_buffer[i] = rl.loadImage(image);
    }
    var texture_buffer = try allocator.alloc(rl.Texture2D, images.len);
    for (texture_buffer, 0..) |_, i| {
        texture_buffer[i] = rl.loadTextureFromImage(image_buffer[i]);
    }
    return texture_buffer;
}

// This is just dumb but will work (mostly futureproof) and is kinda cool
// type here is the number of frames in the animation
pub fn animation(comptime T: type) type {
    return struct {
        current_frame: T = 0,
        frames: []rl.Texture,
        frametime: f32,
        timer: f32 = 0,
        const Anim = @This();
        pub fn step(anim: *Anim, dt: f32, moving: bool) void {
            if (!moving) anim.current_frame = 0
            else {
                anim.timer += dt;
                if (anim.timer > anim.frametime) {
                    anim.timer = 0;
                    anim.current_frame +%= 1;
                }
            }
        }
        pub fn init(frametime: f32, frames: []rl.Texture2D) animation(T) {
            return animation(T){ .frametime = frametime, .frames = frames };
        }
    };
}
