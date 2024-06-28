const std = @import("std");
const rl = @import("raylib");

const Window = @import("Window.zig");
const Input = @import("Input.zig");
const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");
const Player = @import("Player.zig");
const Gui = @import("Gui.zig");
const Json = @import("Json.zig");
const Level = @import("Level.zig");

const color = rl.Color;

// TODO
// Do something with the player data struct
// Spawn bullets that hurt the player
// Organized input system

const fullscreen = true;
pub fn main() anyerror!void {
    rl.setConfigFlags(rl.ConfigFlags.flag_window_resizable);
    rl.initWindow(1600, 900, "~Crimsonlink~");
    rl.setTargetFPS(60);
    defer rl.closeWindow();

    // This allocator is for everything other than the currently active level and it's associated data
    var general_purpouse_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpouse_allocator.allocator();

    const textures = try Textures.loadTextures(gpa);
    defer gpa.free(textures);

    var state = try Statemanager.init(gpa, textures);
    state.level_allocator = state.level_arena.allocator();

    var window = Window{ .width = 1600, .height = 900, .scale = 1, .origin = @splat(0) };
    var world: World = undefined;

    var input_state = Input.InputState{
        .keybinds = std.AutoHashMap(i10, Input.InputAction).init(gpa),
        .active_actions = std.ArrayList(Input.InputAction).init(gpa),
    };
    try Json.loadKeybindings(null, &input_state.keybinds, gpa);

    var player = try Json.loadPlayerData(null, gpa, textures);

    while (!rl.windowShouldClose()) {
        rl.setExitKey(rl.KeyboardKey.key_null);
        if (rl.isWindowResized()) {
            // isn't going to overflow as u16 anyways so who cares
            window.update(@as(u16, @intCast(rl.getRenderWidth())), @as(u16, @intCast(rl.getRenderHeight())), 1600, 900);
        }

        const mb_left: ?@Vector(2, i32) = if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) blk: {
            break :blk @Vector(2, i32){ rl.getMouseX(), rl.getMouseY() };
        } else null;

        switch (state.state) {
            .main_menu => {
                rl.beginDrawing();
                defer rl.endDrawing();
                try Gui.reloadGui(
                    state.gui,
                    window,
                    mb_left,
                    &state,
                    textures,
                    &world,
                    &player,
                );
            },
            .level => {
                try input_state.update();
                try input_state.parse(&world, &player, window, &state, textures);
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.drawTextureEx(
                    world.map.*,
                    rl.Vector2.init(window.origin[0], window.origin[1]),
                    0,
                    window.scale * 4,
                    rl.Color.white,
                );

                // Draw proper door sprites one day
                if (state.current_room) |cr| {
                    if (cr.north != null) {
                        rl.drawRectangle(@divTrunc(window.width, 2), 0, 50, 50, color.green);
                    }
                    if (cr.south != null) {
                        rl.drawRectangle(@divTrunc(window.width, 2), window.height - 50, 50, 50, color.green);
                    }
                    if (cr.east != null) {
                        rl.drawRectangle(0, @divTrunc(window.height, 2), 50, 50, color.green);
                    }
                    if (cr.west != null) {
                        rl.drawRectangle(window.width - 50, @divTrunc(window.height, 2), 50, 50, color.green);
                    }
                }

                // Temporary to traverse the rooms for now
                if (rl.isKeyPressed(rl.KeyboardKey.key_up)) world = try state.loadRoom(textures, &player, state.current_room.?.north.?);
                if (rl.isKeyPressed(rl.KeyboardKey.key_down)) world = try state.loadRoom(textures, &player, state.current_room.?.south.?);
                if (rl.isKeyPressed(rl.KeyboardKey.key_left)) world = try state.loadRoom(textures, &player, state.current_room.?.east.?);
                if (rl.isKeyPressed(rl.KeyboardKey.key_right)) world = try state.loadRoom(textures, &player, state.current_room.?.west.?);

                if (!world.paused) world.iterate(&window, &player);
                try Gui.reloadGui(
                    state.gui,
                    window,
                    mb_left,
                    &state,
                    textures,
                    &world,
                    &player,
                );
            },
            else => {},
        }
        rl.clearBackground(color.black);
    }
}
