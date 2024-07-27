const std = @import("std");
const SDL = @import("sdl2");

const Window = @import("Window.zig");
const Input = @import("Input.zig");
const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");
const Player = @import("Player.zig");
const Gui = @import("Gui.zig");
const Json = @import("Json.zig");
const Level = @import("Level.zig");

// TODO
// Do something with the player data struct

const Dt = struct {
    last: u64,
    now: u64,
    dt: f32 = 0,

    pub fn update(self: *@This()) void {
        self.last = self.now;
        self.now = SDL.getPerformanceCounter();

        self.dt = @as(f32, @floatFromInt(self.now - self.last)) / @as(f32, @floatFromInt(SDL.getPerformanceFrequency()));
    }
};

const fontpath: [:0]const u8 = "assets/neuropol_x.ttf";

const fullscreen = true;
pub fn main() anyerror!void {
    try SDL.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer SDL.quit();

    var sdl_window = try SDL.createWindow(
        "~Crimsonlink~",
        .{ .centered = {} },
        .{ .centered = {} },
        1600,
        900,
        .{
            .vis = .shown,
            .resizable = true,
        },
    );
    defer sdl_window.destroy();

    var dt = Dt{ .now = SDL.getPerformanceCounter(), .last = 0 };

    var renderer = try SDL.createRenderer(sdl_window, null, .{ .accelerated = true });
    defer renderer.destroy();

    try SDL.ttf.init();
    defer SDL.ttf.quit();

    var running = true;

    var window = Window{ .width = 1600, .height = 900, .scale = 1, .origin = @splat(0) };

    const font = SDL.ttf.openFont(fontpath, window.fontsize) catch {
        std.log.err("Failed to open font at {s}", .{fontpath});
        return;
    };

    defer font.close();

    // This allocator is for everything other than the currently active level and it's associated data
    var general_purpouse_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpouse_allocator.allocator();

    const textures = try Textures.loadTextures(&renderer, gpa);

    var state = try Statemanager.init(gpa, textures, &renderer, font);
    state.level_allocator = state.level_arena.allocator();

    var world: World = undefined;

    var input_state = Input.InputState{
        .keybinds = std.AutoHashMap(i10, Input.InputAction).init(gpa),
        .active_actions = std.ArrayList(Input.InputAction).init(gpa),
    };
    try Json.loadKeybindings(null, &input_state.keybinds, gpa);

    var player = try Json.loadPlayerData(null, gpa, textures);

    var goto_room: Level.Direction = .None;

    var mouse_pos: @Vector(2, f32) = @splat(0);

    while (running and !(state.state == .exit_game)) {
        try renderer.setColorRGB(0, 0, 0);
        try renderer.clear();

        dt.update();
        var mb_left: ?@Vector(2, i32) = null;

        while (SDL.pollEvent()) |event| {
            switch (event) {
                .quit => running = false,
                .window => |window_event| {
                    if (window_event.type == .resized) {
                        // isn't going to overflow as u16 anyways so who cares
                        window.update(
                            @as(u16, @intCast(sdl_window.getSize().width)),
                            @as(u16, @intCast(sdl_window.getSize().height)),
                            1600,
                            900,
                        );
                    }
                },
                .mouse_motion => |mouse| {
                    mouse_pos = @Vector(2, f32){ @floatFromInt(mouse.x), @floatFromInt(mouse.y) };
                },
                .mouse_button_down => |mouse_event| {
                    switch (mouse_event.button) {
                        .left => {
                            try input_state.addEvent(501);
                            mb_left = @Vector(2, i32){ mouse_event.x, mouse_event.y };
                        },
                        else => {},
                    }
                },
                .mouse_button_up => |mb| {
                    try input_state.addEvent(switch (mb.button) {
                        .left => -501,
                        else => 0,
                    });
                },
                .key_down => |key| {
                    if (!key.is_repeat)
                        try input_state.addEvent(@as(i10, @intCast(@intFromEnum(key.scancode))));
                },
                .key_up => |key| {
                    // Negative keycodes represent the release of that key
                    if (!key.is_repeat)
                        try input_state.addEvent(-@as(i10, @intCast(@intFromEnum(key.scancode))));
                },
                else => {},
            }
        }

        switch (state.state) {
            .main_menu => {
                try Gui.reloadGui(
                    &renderer,
                    font,
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
                try input_state.parse(&world, &player, window, &state, textures, mouse_pos, &renderer, font);

                try renderer.copyF(world.map, .{
                    .x = window.origin[0],
                    .y = window.origin[1],
                    .width = @as(f32, @floatFromInt(world.dim[0])) * window.scale,
                    .height = @as(f32, @floatFromInt(world.dim[1])) * window.scale,
                }, null);

                if (!world.paused) state.current_room.?.*.completed = try world.iterate(
                    &renderer,
                    &window,
                    &player,
                    &goto_room,
                    textures,
                    dt.dt,
                    input_state.keybinds,
                );
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
                    &renderer,
                    font,
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

        renderer.present();

        if (state.halt_gui_rendering) {
            _ = state.gui_arena.reset(.retain_capacity);
            state.halt_gui_rendering = false;

            try state.reloadGui(textures, &player, &renderer, font);
        }
    }
    state.unloadLevel();
}
