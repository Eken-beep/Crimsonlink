const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Self = @This();

hp: u8,
max_hp: u8,
damage: u8,

pub fn mainAttack(self: *Self, world: *World) !void {
    const player_pos = world.items.items[0].c.pos;
    const mx: f32 = @floatFromInt(rl.getMouseX());
    const my: f32 = @floatFromInt(rl.getMouseY());
    const angle = std.math.atan2(f32, player_pos[1]-my, player_pos[0]-mx);
    try world.addItem(.{
        .type = World.WorldPacket.bullet,
        .x = player_pos[0],
        .y = player_pos[1],
        .vx = -100*@cos(angle),
        .vy = -100*@sin(angle),
        .damage = self.damage,
    });
}
