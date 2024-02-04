const std = @import("std");
const World = @import("World.zig");

const Self = @This();

const PlayerError = error{ OutOfMemory, PlayerNotFound };
// Public declarations //
hp: u8 = 100,
max_hp: u8 = 100,
level: u8 = 0,
attack_timeout: f32 = 0,

// Private declarations
var stats = struct {
    .movementspeed = 10,
    .strength = 5,
};

pub fn addHp(self: *Self, hp: i16) void {
    self.hp = @min(self.max_hp, self.hp + hp);
}

pub fn shoot(self: *Self, world: *World, player: *World.WorldObject, mouse: @Vector(2, i32)) PlayerError!void {
    if (world.items.items.len == 0) return PlayerError.PlayerNotFound;
    self.attack_timeout = 0;
    const mx: f32 = @floatFromInt(mouse[0]);
    const my: f32 = @floatFromInt(mouse[1]);
    const angle = std.math.atan2(f32, player.c.pos[1] - my, player.c.pos[0] - mx);
    const vx: f32 = @cos(angle) * -500;
    const vy: f32 = @sin(angle) * -500;
    std.debug.print("Spawned bullet with velocity, x:{d}, y:{d}\n", .{ vx, vy });
    try world.addItem(World.CollisionType.Bullet, player.c.pos[0], player.c.pos[1], World.Hitbox{ .radius = 20 }, null, null, @Vector(2, f32){ vx, vy });
}
