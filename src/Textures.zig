const std = @import("std");
const rl = @import("raylib");

const images = [_][:0]const u8{
    "assets/betamap2.png",
    "assets/player/MainCharacter1.png",
    "assets/player/MainCharacter2.png",
    "assets/player/MainCharacter3.png",
    "assets/player/MainCharacter4.png",
};

pub fn loadImages(allocator: std.mem.Allocator) ![]rl.Image {
    var buffer = try allocator.alloc(rl.Image, images.len);
    for(buffer, 0..) |_, i| {
        buffer[i] = rl.loadImage(images[i]);
    }
    return buffer;
}

pub fn loadTextures(allocator: std.mem.Allocator, _images: []rl.Image) ![]rl.Texture2D {
    var buffer = try allocator.alloc(rl.Texture2D, images.len);
    for(buffer, 0..) |_, i| {
        buffer[i] = rl.loadTextureFromImage(_images[i]);
    }
    return buffer;
}
