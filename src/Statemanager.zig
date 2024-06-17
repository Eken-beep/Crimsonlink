const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Json = @import("Json.zig");
const Gui = @import("Gui.zig");
const Player = @import("Player.zig");

const Self = @This();

const StateError = error{
    NoLevel,
    OutOfMemory,
    StateNotPausable,
};

pub const Level = struct {
    id: u8,
    last_room: u8,
    rooms: []Room,
    // This one resets upon room reload
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    // more to be added here
};

pub const Room = struct {
    dimensions: @Vector(2, u16),
    enemies: []World.WorldItem,
};

pub const State = enum {
    main_menu,
    level,
    level_paused,
};

state: State,
gui: []Gui.GuiSegment,
gui_arena: std.heap.ArenaAllocator,
current_room: u8,
current_level: ?Level,
allocator: std.mem.Allocator,
// this one resets upon level reload, ie clearing the json data and such
level_arena: std.heap.ArenaAllocator,
level_allocator: std.mem.Allocator,

pub fn init(backing_allocator: std.mem.Allocator, textures: []rl.Texture2D) !Self {
    var result = Self{
        .state = .main_menu,
        .gui = undefined,
        .gui_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .current_room = 1,
        .current_level = undefined,
        .allocator = backing_allocator,
        .level_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .level_allocator = undefined,
    };
    result.gui = try Gui.GuiInit(result.gui_arena.allocator(), .mainmenu_0, textures);
    return result;
}

// The level does not manage the world, rather the layout of the rooms
pub fn loadLevel(self: *Self, id: u8, textures: []rl.Texture2D, player: *Player) !void {
    self.state = .level;
    _ = self.gui_arena.reset(.free_all);
    self.gui = try Gui.GuiInit(self.gui_arena.allocator(), .level, textures);
    self.gui[0].elements[0].hpm.source = &player.*.hp;
    self.gui[0].elements[2].lbl.text_source = &player.*.inventory.dogecoin_str_rep;
    const last_room: u8 = 5;
    const rooms = try self.allocator.alloc(Room, last_room);
    const loadedRoom = try Json.loadRoom(1, 1, self.level_allocator, textures);
    rooms[1] = Room{
        .dimensions = @Vector(2, u16){ 1600, 900 },
        .enemies = loadedRoom.enemies,
    };
    rooms[2] = Room{
        .dimensions = loadedRoom.dimensions,
        .enemies = loadedRoom.enemies,
    };
    switch (id) {
        1 => {
            self.current_level = Level{
                .id = id,
                .rooms = rooms,
                .last_room = last_room,
                .arena = std.heap.ArenaAllocator.init(self.allocator),
                // Weird pointer gymnasics??
                .allocator = undefined,
            };
            self.current_level.?.allocator = self.current_level.?.arena.allocator();
        },
        else => {},
    }
    self.current_room = 0;
}

pub fn nextRoom(self: *Self, textures: []rl.Texture2D, player: *Player) StateError!World {
    if (self.current_level) |level| {
        _ = self.current_level.?.arena.reset(.free_all);
        if (self.current_room < level.last_room) {
            self.current_room += 1;
            // use the dimensions stored in the level
            var room = try World.init(
                level.rooms[self.current_room].dimensions,
                &textures[Textures.getImageId("betamap2")[0]],
                self.current_level.?.allocator,
            );
            try room.addItem(.{
                .type = World.WorldPacket.player,
                .x = 400,
                .y = 200,
                .animation = Textures.animation(u2).init(
                    0.5,
                    textures[Textures.getImageId("MainCharacter")[0]..Textures.getImageId("MainCharacter")[1]],
                ),
                .weapon = player.forehand,
            });
            try room.items.appendSlice(level.rooms[self.current_room].enemies);
            // Placeholder texture
            try room.addItem(.{ .type = World.WorldPacket.item, .x = 500, .y = 50, .sprite = &textures[Textures.getImageId("doge")[0]], .itemtype = .money, .ammount = 5 });
            try room.addItem(.{ .type = World.WorldPacket.static, .x = 800, .y = 100, .sprite = &textures[Textures.getImageId("doge")[0]] });
            return room;
        }
    }
    return StateError.NoLevel;
}

pub fn pauseLevel(self: *Self, world: *World, textures: []rl.Texture2D, player: *Player) anyerror!void {
    //if (self.state != .level or self.state != .level_paused) return StateError.StateNotPausable;
    world.paused = !world.paused;
    const state: Gui.GuiState = if (world.paused) .level_paused else .level;
    _ = self.gui_arena.reset(.free_all);
    self.gui = try Gui.GuiInit(
        self.gui_arena.allocator(),
        state,
        textures,
    );
    if (!world.paused) {
        self.gui[0].elements[0].hpm.source = &player.*.hp;
        self.gui[0].elements[2].lbl.text_source = &player.*.inventory.dogecoin_str_rep;
    }
}
