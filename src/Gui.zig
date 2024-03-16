const std = @import("std");
const rl = @import("raylib");

const Window = @import("Window.zig");
const Player = @import("Player.zig");
const Textures = @import("Textures.zig");

pub fn drawLevelGui(window: Window, textures: []rl.Texture2D, player: Player) void {
    const s = window.scale;

    for (0..player.hp) |i| {
        const fi: f32 = @floatFromInt(i);
        rl.drawTextureEx(textures[Textures.sprite.heart], rl.Vector2.init((10 + 90*fi) * s, 10 * s), 0, s, rl.Color.white);
    }
}
