const std = @import("std");
const rl = @import("raylib");

const Window = @import("Window.zig");
const Input = @import("Input.zig");
const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");
const Player = @import("Player.zig");
const Gui = @import("Gui.zig");

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

    var state = Statemanager { .state = .main_menu, .allocator = gpa, .arena = std.heap.ArenaAllocator.init(gpa), .current_room = undefined, .current_level = undefined };
    var window = Window { .width = 1600, .height = 900, .scale = 1, .origin = @splat(0) };
    var world: World = undefined;

    var player = Player{ .hp = 5, .max_hp = 5, .damage = 5 };

    while (!rl.windowShouldClose()) {
        if(rl.isWindowResized()) {
            // isn't going to overflow as u16 anyways so who cares
            window.update(@as(u16, @intCast(rl.getRenderWidth())), @as(u16, @intCast(rl.getRenderHeight())), 1600, 900);
        }
        const key = rl.getKeyPressed();
        switch(state.state) {
            .main_menu => {
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.drawText("Press space to start", window.width/2, window.height/2, 28, color.gray);
                if(rl.isKeyDown(rl.KeyboardKey.key_space)) {
                    state.state = .level;
                    try state.loadLevel(1);
                    // we only pass the textures as an argement here to add the player in the beginning
                    world = try state.nextRoom(textures);
                }
            },
            .level => {
                if (key == .key_enter) try player.mainAttack(&world);
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.drawTextureEx(world.map.*, rl.Vector2.init(window.origin[0], window.origin[1]), 0, window.scale, rl.Color.white);

                Gui.drawLevelGui(window, textures, player);

                world.iterate(&window);
                
            }
        }
        rl.clearBackground(color.black);
    }
}
