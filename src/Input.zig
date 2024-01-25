const std = @import("std");
const rl = @import("raylib");

const key = rl.KeyboardKey;

const direction = enum { n, s, e, w, ne, nw, se, sw };

pub fn updateMovements(s: f32) @Vector(2, f32) {
    // zls decided to format this, not me
    const dir: ?direction = if (rl.isKeyDown(key.key_up) and rl.isKeyDown(key.key_left)) direction.nw else if (rl.isKeyDown(key.key_up) and rl.isKeyDown(key.key_right)) direction.ne else if (rl.isKeyDown(key.key_down) and rl.isKeyDown(key.key_left)) direction.sw else if (rl.isKeyDown(key.key_down) and rl.isKeyDown(key.key_right)) direction.se else if (rl.isKeyDown(key.key_up)) direction.n else if (rl.isKeyDown(key.key_down)) direction.s else if (rl.isKeyDown(key.key_left)) direction.w else if (rl.isKeyDown(key.key_right)) direction.e else null;
    if (dir) |d| {
        return switch (d) {
            .n => @Vector(2, f32){ 0, -s },
            .s => @Vector(2, f32){ 0, s },
            .e => @Vector(2, f32){ s, 0 },
            .w => @Vector(2, f32){ -s, 0 },
            .ne => @Vector(2, f32){ s, -s },
            .nw => @Vector(2, f32){ -s, -s },
            .se => @Vector(2, f32){ s, s },
            .sw => @Vector(2, f32){ -s, s },
        };
    } else return @Vector(2, f32){ 0, 0 };
}
