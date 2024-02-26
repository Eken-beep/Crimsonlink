const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Textures = @import("Textures.zig");

const Self = @This();

const StateError = error { NoLevel, OutOfMemory };

const Level = struct {
    id: u8,
    last_room: u8,
    rooms: []@Vector(2, u16),
    // more to be added here
};

pub const State = enum {
    main_menu,
    level,
};

state: State,
current_room: u8,
current_level: ?Level,
arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,

// The level does not manage the world, rather the layout of the rooms
pub fn loadLevel(self: *Self, id: u8) !void {
    self.state = .level;
    const last_room: u8 = 5;
    const rooms = try self.allocator.alloc(@Vector(2, u16), last_room);
    rooms[0] = @Vector(2, u16){1600, 900};
    rooms[1] = @Vector(2, u16){1600, 900};
    rooms[2] = @Vector(2, u16){900, 900};
    rooms[3] = @Vector(2, u16){1600, 900};
    rooms[4] = @Vector(2, u16){1100, 300};
    switch(id) {
        1 => {
            self.current_level = Level { .id = id, .rooms = rooms, .last_room = last_room };
            self.current_room = 0;
        },
        else => {},
    }
}

pub fn nextRoom(self: *Self, textures: []rl.Texture2D) StateError!World {
    if (self.current_level) |level| {
        _ = self.arena.reset(.free_all);
        if (self.current_room < level.last_room) {
            self.current_room += 1;
            // use the dimensions stored in the level
            var room = try World.init(level.rooms[self.current_room], &textures[1], self.arena.allocator());
            try room.addItem(.{.type = World.WorldPacket.player, .x = 400, .y = 200, .animation = Textures.animation(u2).init(0.5, textures[2..])});
            return room;
        }
    } 
    return StateError.NoLevel;
}
