const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Json = @import("Json.zig");

const Self = @This();

const StateError = error{ NoLevel, OutOfMemory };

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
};

state: State,
current_room: u8,
current_level: ?Level,
allocator: std.mem.Allocator,
// this one resets upon level reload, ie clearing the json data and such
level_arena: std.heap.ArenaAllocator,
level_allocator: std.mem.Allocator,

pub fn init(backing_allocator: std.mem.Allocator) Self {
    return Self{
        .state = .main_menu,
        .current_room = 1,
        .current_level = undefined,
        .allocator = backing_allocator,
        .level_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .level_allocator = undefined,
    };
}

// The level does not manage the world, rather the layout of the rooms
pub fn loadLevel(self: *Self, id: u8, textures: []rl.Texture2D) !void {
    self.state = .level;
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

pub fn nextRoom(self: *Self, textures: []rl.Texture2D, world: *World) StateError!World {
    if (self.current_level) |level| {
        // This is because the player gets stuck in the old velocity if room is changed while holding down a movementkey
        // Don't know how to patch this otherwise right now
        const prev_playervel: ?@Vector(2, f32) = if (self.current_room != 0) world.items.items[0].c.vel else null;
        _ = self.current_level.?.arena.reset(.free_all);
        if (self.current_room < level.last_room) {
            self.current_room += 1;
            // use the dimensions stored in the level
            var room = try World.init(level.rooms[self.current_room].dimensions, &textures[1], self.current_level.?.allocator);
            try room.addItem(.{ .type = World.WorldPacket.player, .x = 400, .y = 200, .animation = Textures.animation(u2).init(0.5, textures[3..7]) });
            if (prev_playervel) |pvel| room.items.items[0].c.vel = pvel;
            try room.items.appendSlice(level.rooms[self.current_room].enemies);
            // Placeholder texture
            try room.addItem(.{ .type = World.WorldPacket.item, .x = 50, .y = 50, .sprite = &textures[3], .itemtype = .slime, .ammount = 1 });
            return room;
        }
    }
    return StateError.NoLevel;
}
