const std = @import("std");
const rl = @import("raylib");

const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Json = @import("Json.zig");
const Gui = @import("Gui.zig");
const Player = @import("Player.zig");
const Level = @import("Level.zig");

const Self = @This();

const StateError = error{
    NoLevel,
    OutOfMemory,
    StateNotPausable,
};

pub const State = enum {
    main_menu,
    level,
    level_paused,
};

state: State,
gui: []Gui.GuiSegment,
gui_arena: std.heap.ArenaAllocator,
gui_state: Gui.GuiState,
current_room: ?*Level.Room,
current_level: ?Level.Level,
allocator: std.mem.Allocator,
// this one resets upon level reload, ie clearing the json data and such
level_arena: std.heap.ArenaAllocator,
level_allocator: std.mem.Allocator,

pub fn init(backing_allocator: std.mem.Allocator, textures: []rl.Texture2D) !Self {
    var result = Self{
        .state = .main_menu,
        .gui = undefined,
        .gui_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .gui_state = .mainmenu_0,
        .current_level = null,
        .current_room = null,
        .allocator = backing_allocator,
        .level_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .level_allocator = undefined,
    };
    result.gui = try Gui.GuiInit(result.gui_arena.allocator(), .mainmenu_0, textures);
    return result;
}

// The level does not manage the world, rather the layout of the rooms
pub fn loadLevel(self: *Self, id: u8, textures: []rl.Texture2D, player: *Player, world: *World) !void {
    self.state = .level;
    self.gui_state = .level;

    try self.reloadGui(textures, player);

    self.current_level = try Json.getLevel(id, self.level_allocator, textures);
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
pub fn reloadGui(self: *Self, textures: []rl.Texture2D, player: *Player) !void {
    // We keep the capacity when reloading the gui during a level or inside a menu
    _ = self.gui_arena.reset(.retain_capacity);

    switch (self.gui_state) {
        .mainmenu_0 => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .mainmenu_0, textures);
        },
        .level => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .level, textures);
            self.gui[0].elements[0].hpm.source = &player.*.hp;
            self.gui[0].elements[2].lbl.text_source = &player.*.inventory.dogecoin_str_rep;
        },
        .level_paused => {
            self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .level_paused, textures);
        },
        else => unreachable,
    }
}

pub fn loadRoom(self: *Self, textures: []rl.Texture2D, player: *Player, room: *Level.Room) StateError!World {
    self.current_room = room;
    // use the dimensions stored in the level
    var world = try World.init(
        room.*.dimensions,
        room.*.texture,
        self.level_allocator,
    );
    try world.addItem(.{
        .type = World.WorldPacket.player,
        .x = 400,
        .y = 200,
        .animation = Textures.animation(u2).init(
            0.5,
            textures[comptime Textures.getImageId("Main_New")[0]..comptime Textures.getImageId("MainCharacter")[1]],
        ),
        .weapon = player.forehand,
    });
    if (room.*.north != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.North,
        .texture = &textures[Textures.getImageId("Gun 1")[0]],
    });
    if (room.*.south != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.South,
        .texture = &textures[Textures.getImageId("Gun 1")[0]],
    });
    if (room.*.east != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.East,
        .texture = &textures[Textures.getImageId("Gun 1")[0]],
    });
    if (room.*.west != null) try world.addItem(.{
        .type = World.WorldPacket.door,
        .side = Level.Direction.West,
        .texture = &textures[Textures.getImageId("Gun 1")[0]],
    });
    if (room.*.enemies) |enemies| if (!room.*.completed) try world.items.appendSlice(enemies);
    return world;
}

pub fn pauseLevel(self: *Self, world: *World, textures: []rl.Texture2D, player: *Player) anyerror!void {
    //if (self.state != .level or self.state != .level_paused) return StateError.StateNotPausable;
    world.paused = !world.paused;
    self.gui_state = if (world.paused) .level_paused else .level;
    try self.reloadGui(textures, player);
}
