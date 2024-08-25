const std = @import("std");
const SDL = @import("sdl2");

const World = @import("World.zig");
const Player = @import("Player.zig");
const Window = @import("Window.zig");
const Statemanager = @import("Statemanager.zig");
const Textures = @import("Textures.zig");

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

    menu_select,
    pause,
};

pub const InputState = struct {
    // Keys 1 < 500 is for the keyboard, the mouse buttons are then added ontop of that and are 501, 502, 503
    // Negative keynumbers are for when said key is released
    keybinds: std.AutoHashMap(i10, InputAction),
    active_actions: std.ArrayList(InputAction),

    const Self = @This();
    pub fn addEvent(self: *Self, keycode: i10) !void {
        try self.active_actions.append(self.keybinds.get(keycode) orelse return);
        if (keycode > 0 and keycode < 500) try self.active_actions.append(.menu_select);
    }

    pub fn parse(
        self: *Self,
        world: *World,
        player: *Player,
        window: Window,
        state: *Statemanager,
        textures: Textures.TextureMap,
        mouse: @Vector(2, f32),
        r: *SDL.Renderer,
        font: SDL.ttf.Font,
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
                .shoot_begin => try player.mainAttack(mouse, world, window),

                .menu_select => if (state.dialog != null) {
                    state.dialog = state.dialog.?.destroy();
                },
                .pause => try state.pauseLevel(world, textures, player, r, font),
                else => {},
            }
        }
    }
};
