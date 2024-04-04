const std = @import("std");
const rl = @import("raylib");

const Window = @import("Window.zig");
const Player = @import("Player.zig");
const Textures = @import("Textures.zig");

pub fn drawLevelGui(window: Window, textures: []rl.Texture2D, player: Player) !void {
    const s = window.scale;

    // HP
    for (0..player.hp) |i| {
        const fi: f32 = @floatFromInt(i);
        rl.drawTextureEx(textures[Textures.sprite.heart], rl.Vector2.init((10 + 90 * fi) * s, 10 * s), 0, s, rl.Color.white);
    }

    // Money
    rl.drawTextureEx(
        textures[Textures.sprite.dogecoin],
        rl.Vector2.init(10 * s, 20 * s + @as(f32, @floatFromInt(textures[Textures.sprite.heart].height)) * s),
        0,
        s * 0.5,
        rl.Color.white,
    );
    var coin_buffer: [3:0]u8 = undefined;
    rl.drawText(
        try std.fmt.bufPrintZ(&coin_buffer, "{d}", .{player.inventory.dogecoins}),
        @as(i32, @intFromFloat(10 * s)) + @divFloor(textures[Textures.sprite.dogecoin].height, 2),
        @as(i32, @intFromFloat(@as(f32, @floatFromInt(textures[Textures.sprite.heart].height)) * s + 30 * s)),
        28,
        rl.Color.gray,
    );
}
