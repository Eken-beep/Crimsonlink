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

        const mb_left: ?@Vector(2, i32) = if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) blk: {
            break :blk @Vector(2, i32){ rl.getMouseX(), rl.getMouseY() };
        } else null;

        switch (state.state) {
            .main_menu => {
                rl.beginDrawing();
                defer rl.endDrawing();
                rl.drawText("Press space to start", window.width / 2, window.height / 2, 28, color.gray);
                const testGuiBtn: Gui.GuiItem = .{ .btn = .{
                    .text = "Start",
                    .width = 300,
                    .height = 50,
                    .border_color = color.white,
                    .bg_color = color.gray,
                    .fg_color = color.black,
                    .action = btn_launchGame,
                } };
                try Gui.reloadGui(
                    &[_]Gui.GuiSegment{
                        .{
                            .pos = .top_middle,
                            .columns = 1,
                            .column_width = 300,
                            .elements = &[_]Gui.GuiItem{
                                .{ .spc = 300 },
                                testGuiBtn,
                            },
                        },
                    },
                    window,
                    mb_left,
                    &state,
                    textures,
                    &world,
                );
            },
            .level => {
                if (world.completed) world = try state.nextRoom(textures);
                try input_state.update();
                try input_state.parse(&world, &player);
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.drawTextureEx(world.map.*, rl.Vector2.init(window.origin[0], window.origin[1]), 0, window.scale, rl.Color.white);

                if (!world.paused) world.iterate(&window, &player);

                try Gui.drawLevelGui(window, textures, player);
            },
        }
        rl.clearBackground(color.black);
    }
}

fn btn_launchGame(state: *Statemanager, textures: []rl.Texture2D, world: *World) anyerror!void {
    state.*.state = .level;
    try state.*.loadLevel(1, textures);
    world.* = try state.*.nextRoom(textures);
}
