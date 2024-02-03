const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");

// Enemies are here only aware of the player
pub fn updateEnemy(e: World.WorldObject, player: World.WorldObject) World.WorldObject {
    var result = e;
    const px = player.c.pos[0];
    const py = player.c.pos[1];
    const ex = e.c.pos[0];
    const ey = e.c.pos[1];
    const angle = std.math.atan2(f32, ey - py, ex - px);
    // should probably pass the frametime as an argument but who cares
    result.c.pos[0] += @cos(angle) * -50 * rl.getFrameTime();
    result.c.pos[1] += @sin(angle) * -50 * rl.getFrameTime();
    return result;
}
