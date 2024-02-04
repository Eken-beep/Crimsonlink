const std = @import("std");
const World = @import("World.zig");
const rl = @import("raylib");

const Self = @This();

pub const State = enum { Level, Menu };

const LevelLoadError = error{ OutOfMemory, LevelNotFound };

state: State,
// We keep the arena allocator in here to reset it everytime the room is reloaded
arena_allocator: std.heap.ArenaAllocator,

// a bit undescriptive as this only loads the next room right now
// the same function should load both room and level soon
// level if you're not in a room and room if you have already started a level
pub fn loadLevel(self: *Self, world: *?World, level: u8, images: []rl.Image) LevelLoadError!World {
    const allocator = self.arena_allocator.allocator();
    if (world.* != null) {
        world.*.?.deinit();
        // We should probably handle this at some point
        const result: bool = self.arena_allocator.reset(.free_all);
        std.debug.print("Room reloaded, Memory freed: {any}\n", .{result});
    }
    switch (level) {
        1 => {
            var w: World = try World.init(allocator, 1600, 900, images);
            // We add this before the world processes another frame to avoid having to pause the rest of the game when the player doesn't exist yet
            try w.addItem(World.CollisionType.Player, 400, 225, World.Hitbox{ .radius = 5 }, null, w.textures[1..5], @Vector(2, f32){ 0, 0 });
            try w.addItem(World.CollisionType.Enemy, 1400, 400, World.Hitbox{ .radius = 5 }, &w.textures[6], null, @Vector(2, f32){ 0, 0 });
            return w;
        },
        else => return LevelLoadError.LevelNotFound,
    }
}
