const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Player = @import("Player.zig");
const Window = @import("Window.zig");
const Statemanager = @import("Statemanager.zig");
const Textures = @import("Textures.zig");

const key = rl.KeyboardKey;

pub const InputAction = enum {
    // One for when a movementkey is pressed
    moveup,
    moveleft,
    movedown,
    moveright,
    // One for when a movementkey is released
    haltup,
    haltleft,
    haltdown,
    haltright,

    shoot_begin,
    shoot_end,

    pause,
};

pub const InputState = struct {
    // Keys 1 thru 336 is for the keyboard, the mouse buttons are then added ontop of that and are 501, 502, 503
    // Negative keynumbers are for when said key is released
    keybinds: std.AutoHashMap(i10, InputAction),
    active_actions: std.ArrayList(InputAction),

    const Self = @This();
    pub fn update(self: *Self) !void {
        var iterator = self.keybinds.keyIterator();
        while (iterator.next()) |keycodeptr| {
            const keycode = keycodeptr.*;
            if (keycode >= 0 and keycode < 501) {
                if (rl.isKeyPressed(@as(rl.KeyboardKey, @enumFromInt(@as(c_int, @intCast(keycode)))))) {
                    try self.active_actions.append(self.keybinds.get(keycode).?);
                }
            } else if (keycode > -501 and keycode < 501) {
                if (rl.isKeyReleased(@as(rl.KeyboardKey, @enumFromInt(@abs(keycode))))) {
                    try self.active_actions.append(self.keybinds.get(keycode).?);
                }
            } else if (keycode > 500) {
                if (rl.isMouseButtonPressed(@as(rl.MouseButton, @enumFromInt(keycode - 501)))) {
                    try self.active_actions.append(self.keybinds.get(keycode).?);
                }
            } else {
                if (rl.isMouseButtonReleased(@as(rl.MouseButton, @enumFromInt(@abs(keycode) - 501)))) {
                    try self.active_actions.append(self.keybinds.get(keycode).?);
                }
            }
        }
    }

    pub fn parse(
        self: *Self,
        world: *World,
        player: *Player,
        window: Window,
        state: *Statemanager,
        textures: Textures.TextureMap,
    ) !void {
        while (self.active_actions.items.len > 0) {
            switch (self.active_actions.pop()) {
                .moveup => world.items.items[0].c.vel += @Vector(2, f32){ 0, -player.movementspeed },
                .moveleft => world.items.items[0].c.vel += @Vector(2, f32){ -player.movementspeed, 0 },
                .movedown => world.items.items[0].c.vel += @Vector(2, f32){ 0, player.movementspeed },
                .moveright => world.items.items[0].c.vel += @Vector(2, f32){ player.movementspeed, 0 },

                .haltup => world.items.items[0].c.vel += @Vector(2, f32){ 0, player.movementspeed },
                .haltleft => world.items.items[0].c.vel += @Vector(2, f32){ player.movementspeed, 0 },
                .haltdown => world.items.items[0].c.vel += @Vector(2, f32){ 0, -player.movementspeed },
                .haltright => world.items.items[0].c.vel += @Vector(2, f32){ -player.movementspeed, 0 },

                // Shooting
                .shoot_begin => try player.mainAttack(world, window),

                .pause => try state.pauseLevel(world, textures, player),
                else => {},
            }
        }
    }
};
