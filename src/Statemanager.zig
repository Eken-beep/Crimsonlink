const std = @import("std");
const World = @import("World.zig");
const rl = @import("raylib");

pub const State = enum { Level, Menu };

const LevelLoadError = error{ OutOfMemory, LevelNotFound };

pub fn loadLevel(level: u8, allocator: std.mem.Allocator, images: []rl.Image) LevelLoadError!World {
    switch (level) {
        1 => return World.init(allocator, 1600, 900, images),
        else => return LevelLoadError.LevelNotFound,
    }
}
