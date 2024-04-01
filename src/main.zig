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

    var state = Statemanager.init(gpa);
    state.level_allocator = state.level_arena.allocator();
    var window = Window{ .width = 1600, .height = 900, .scale = 1, .origin = @splat(0) };
    var world: World = undefined;

    var input_state = Input.InputState{
        .keybinds = std.AutoHashMap(i10, Input.InputAction).init(gpa),
        .active_actions = std.ArrayList(Input.InputAction).init(gpa),
    };
    try Json.loadKeybindings(null, &input_state.keybinds, gpa);

    var player = try Json.loadPlayerData(null, gpa);

    while (!rl.windowShouldClose()) {
        if (rl.isWindowResized()) {
            // isn't going to overflow as u16 anyways so who cares
            window.update(@as(u16, @intCast(rl.getRenderWidth())), @as(u16, @intCast(rl.getRenderHeight())), 1600, 900);
        }

        switch (state.state) {
            .main_menu => {
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.drawText("Press space to start", window.width / 2, window.height / 2, 28, color.gray);
                if (rl.isKeyDown(rl.KeyboardKey.key_space)) {
                    state.state = .level;
                    try state.loadLevel(1, textures);
                    // we only pass the textures as an argement here to add the player in the beginning
                    world = try state.nextRoom(textures, &world);
                }
            },
            .level => {
                if (world.completed) world = try state.nextRoom(textures, &world);
                try input_state.update();
                try input_state.parse(&world, &player);
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.drawTextureEx(world.map.*, rl.Vector2.init(window.origin[0], window.origin[1]), 0, window.scale, rl.Color.white);

                Gui.drawLevelGui(window, textures, player);

                if (!world.paused) world.iterate(&window, &player);
            },
        }
        rl.clearBackground(color.black);
    }
}
