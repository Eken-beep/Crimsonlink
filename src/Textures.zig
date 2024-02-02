const std = @import("std");
const rl = @import("raylib");

pub const all_images = [_][:0]const u8{
    "assets/betamap1.png",
    "assets/Maincharacter1.png",
    "assets/Enemy1.png",
};

pub fn loadImages(allocator: std.mem.Allocator, images: [all_images.len][:0]const u8) ![]rl.Image {
    var result: []rl.Image = try allocator.alloc(rl.Image, images.len);
    for (images, 0..) |image, i| {
        result[i] = rl.loadImage(image);
    }
    return result;
}
