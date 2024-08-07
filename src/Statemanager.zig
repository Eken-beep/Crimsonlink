const std = @import("std");
const SDL = @import("sdl2");

const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Json = @import("Json.zig");
const Gui = @import("Gui.zig");
const Player = @import("Player.zig");
const Level = @import("Level.zig");

const Self = @This();

const StateError = error{
    SdlError,
    NoLevel,
    OutOfMemory,
    StateNotPausable,
};

pub const State = enum {
    main_menu,
    level,
    level_paused,
    exit_game,
};

state: State,
gui: []Gui.GuiSegment,
halt_gui_rendering: bool,
gui_arena: std.heap.ArenaAllocator,
gui_state: Gui.GuiState,
gui_parent_state: Gui.GuiState,
current_room: ?*Level.Room,
current_level: ?Level.Level,
allocator: std.mem.Allocator,
// this one resets upon level reload, ie clearing the json data and such
level_arena: std.heap.ArenaAllocator,
level_allocator: std.mem.Allocator,

pub fn init(backing_allocator: std.mem.Allocator, textures: Textures.TextureMap, r: *SDL.Renderer, font: SDL.ttf.Font) !Self {
    var result = Self{
        .state = .main_menu,
        .gui = undefined,
        .halt_gui_rendering = false,
        .gui_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .gui_state = .mainmenu_0,
        .gui_parent_state = .none,
        .current_level = null,
        .current_room = null,
        .allocator = backing_allocator,
        .level_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .level_allocator = undefined,
    };
    result.gui = try Gui.GuiInit(result.gui_arena.allocator(), .mainmenu_0, textures, r, font);
    return result;
}

// The level does not manage the world, rather the layout of the rooms
pub fn loadLevel(
    self: *Self,
    r: *SDL.Renderer,
    id: u8,
    textures: Textures.TextureMap,
    player: *Player,
    world: *World,
) !void {
    self.state = .level;
    self.gui_state = .level;

    self.current_level = try Json.getLevel(r, id, self.level_allocator, textures);
    // Setting the current room to the first room (spawn)
    // Meanwhile the level always holds the pointer to the spawn
    // This can change when the player moves
    self.current_room = self.current_level.?.rooms;
    world.* = try self.loadRoom(textures, player, self.current_level.?.rooms);
}

pub fn unloadLevel(self: *Self) void {
    self.state = .main_menu;
    _ = self.level_arena.reset(.free_all);
}

// This does all the extra around loading a gui
// like setting the pointers to the data
pub fn reloadGui(self: *Self, textures: Textures.TextureMap, player: *Player, r: *SDL.Renderer, font: SDL.ttf.Font) !void {
    // We keep the capacity when reloading the gui during a level or inside a menu
    if (!self.halt_gui_rendering) _ = self.gui_arena.reset(.retain_capacity);

    switch (self.gui_state) {
        .mainmenu_0 => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .mainmenu_0, textures, r, font);
        },
        .level => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .level, textures, r, font);
            self.gui[0].elements[0].hpm.source = &player.*.hp;
            self.gui[0].elements[2].lbl.text_source = &player.*.current_score_str;
            self.gui[0].elements[4].lbl.text_source = &player.*.inventory.dogecoin_str_rep;

            // To update the text
            player.addScore(0, 0);

            // This is always the inventory, otherwise ded
            std.debug.assert(self.gui[1].elements[0] == .inventory_slot);
            for (self.gui[1].elements, 0..) |*slot, i| {
                slot.inventory_slot.slot_source = &player.*.inventory.items[i];
            }
        },
        .level_paused => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .level_paused, textures, r, font);
        },
        .settings_main => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .settings_main, textures, r, font);
        },
        else => unreachable,
    }
}

pub fn loadRoom(self: *Self, textures: Textures.TextureMap, player: *Player, room: *Level.Room) StateError!World {
    self.current_room = room;
    // use the dimensions stored in the level
    var world = try World.init(
        room.dimensions,
        room.texture,
        self.level_allocator,
    );
    try world.addItem(.{
        .type = World.WorldPacket.player,
        .x = @as(f32, @floatFromInt(@divTrunc(room.dimensions[0], 2) - 18 * 2)),
        .y = @as(f32, @floatFromInt(@divTrunc(room.dimensions[1], 2) - 52 * 2)),
        .animation = Textures.Animation{
            .nr_frames = 5,
            .frametime = (0.1),
            .avalilable_directions = 8,
            .frames = blk: {
                // TODO clean this memory after unloading room, leaks until everything is unloaded in the level_allocator
                const framebuffer = try self.level_allocator.alloc(Textures.AnimationData, 8);
                framebuffer[0] = Textures.AnimationData.init("player_0", textures);
                framebuffer[1] = Textures.AnimationData.init("player_1", textures);
                framebuffer[2] = Textures.AnimationData.init("player_2", textures);
                framebuffer[3] = Textures.AnimationData.init("player_3", textures);
                framebuffer[4] = Textures.AnimationData.init("player_4", textures);
                framebuffer[5] = Textures.AnimationData.init("player_5", textures);
                framebuffer[6] = Textures.AnimationData.init("player_6", textures);
                framebuffer[7] = Textures.AnimationData.init("player_7", textures);
                break :blk framebuffer;
            },
        },
        .weapon = player.forehand,
    });
    if (room.*.north != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.North,
        .sprite = Textures.getTexture(textures, "Gun").slice[0],
    });
    if (room.*.south != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.South,
        .sprite = Textures.getTexture(textures, "Gun").slice[0],
    });
    if (room.*.east != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.East,
        .sprite = Textures.getTexture(textures, "Gun").slice[0],
    });
    if (room.*.west != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.West,
        .sprite = Textures.getTexture(textures, "Gun").slice[0],
    });
    if (room.*.enemies) |enemies| if (!room.*.completed) try world.items.appendSlice(enemies);
    return world;
}

pub fn pauseLevel(
    self: *Self,
    world: *World,
    textures: std.StringArrayHashMap(Textures.TextureStore),
    player: *Player,
    r: *SDL.Renderer,
    font: SDL.ttf.Font,
) !void {
    //if (self.state != .level or self.state != .level_paused) return StateError.StateNotPausable;
    world.paused = !world.paused;
    self.gui_state = if (world.paused) .level_paused else .level;
    try self.reloadGui(textures, player, r, font);
}
