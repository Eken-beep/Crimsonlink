const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Self = @This();

const BASEXP = 100;

hp: u8,
max_hp: u8,
damage: u8,

xp: u16 = 0,
requiredxp: u16 = BASEXP,
level: u16 = 0,

pub fn mainAttack(self: *Self, world: *World) !void {
    const player_pos = world.items.items[0].c.pos + world.items.items[0].c.centerpoint;
    const mx: f32 = @floatFromInt(rl.getMouseX());
    const my: f32 = @floatFromInt(rl.getMouseY());
    const angle = std.math.atan2(f32, player_pos[1] - my, player_pos[0] - mx);
    try world.addItem(.{
        .type = World.WorldPacket.bullet,
        .x = player_pos[0],
        .y = player_pos[1],
        .vx = -1000 * @cos(angle),
        .vy = -1000 * @sin(angle),
        .damage = self.damage,
    });
}

pub fn addXp(self: *Self, ammount: u16) void {
    self.xp += ammount;
    if (self.xp > self.requiredxp) {
        self.requiredxp = @intFromFloat(BASEXP * std.math.pow(f32, 1.08, @as(f32, @floatFromInt(self.level))));
        self.level += 1;
        self.xp = 0;
    }
}
