const std = @import("std");
const rl = @import("raylib");

const key = rl.KeyboardKey;

const ActionState = struct {
    hold: bool = false,
    active: bool = false,
};

pub const InputState = struct {
    // 126 relevant keyboardkeys and 3 mousebuttons
    keystates: [129]u8,
};

pub fn playerMovement(speed: f32) @Vector(2, f32) {
    const x: f32 = if (rl.isKeyDown(key.key_a)) -1 else if (rl.isKeyDown(key.key_d)) 1 else 0;
    const y: f32 = if (rl.isKeyDown(key.key_w)) -1 else if (rl.isKeyDown(key.key_s)) 1 else 0;
    const result = @Vector(2, f32){ x * speed, y * speed };
    return result;
}
