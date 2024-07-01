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
    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true });
    rl.setExitKey(rl.KeyboardKey.key_null);
    rl.initWindow(1600, 900, "~Crimsonlink~");
    rl.setTargetFPS(60);
    defer rl.closeWindow();

    // This allocator is for everything other than the currently active level and it's associated data
    var general_purpouse_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpouse_allocator.allocator();

    const textures = try Textures.loadTextures(gpa);

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

    var goto_room: Level.Direction = .None;

    while (!rl.windowShouldClose()) {
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
                    world.map,
                    rl.Vector2.init(window.origin[0], window.origin[1]),
                    0,
                    window.scale * 4,
                    rl.Color.white,
                );

                if (!world.paused) state.current_room.?.*.completed = world.iterate(&window, &player, &goto_room);
                if (state.current_room.?.*.completed) {
                    state.current_room.?.*.enemies = null;

                    switch (goto_room) {
                        .None => {},
                        .North => world = try state.loadRoom(textures, &player, state.current_room.?.north.?),
                        .South => world = try state.loadRoom(textures, &player, state.current_room.?.south.?),
                        .East => world = try state.loadRoom(textures, &player, state.current_room.?.east.?),
                        .West => world = try state.loadRoom(textures, &player, state.current_room.?.west.?),
                    }
                }

                // Reset this immediately after switching room
                goto_room = .None;
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
            else => unreachable,
        }
        rl.clearBackground(color.black);
    }
    state.unloadLevel();
}
