const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Textures = @import("Textures.zig");

const Self = @This();

const StateError = error{ NoLevel, OutOfMemory };

const Level = struct {
    id: u8,
    last_room: u8,
    rooms: []Room,
    // more to be added here
};

const Room = struct {
    dimensions: @Vector(2, u16),
    enemies: [5]World.WorldItem,
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
pub fn loadLevel(self: *Self, id: u8, textures: []rl.Texture2D) !void {
    self.state = .level;
    const last_room: u8 = 5;
    const rooms = try self.allocator.alloc(Room, last_room);
    rooms[0] = Room{
        .dimensions = @Vector(2, u16){ 1600, 900 },
        // This should eventually be read from somewhere else and not hardcoded
        .enemies = [5]World.WorldItem{
            .{
                .c = World.Collider{
                    .pos = @Vector(2, f32){ 1500, 800 },
                    .vel = @splat(0),
                    .hitbox = @splat(30),
                    .centerpoint = @splat(15),
                },
                .hp = 100,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.animation(u3).init(0.3, textures[Textures.sprite.enemies.blooby.s .. Textures.sprite.enemies.blooby.s + Textures.sprite.enemies.blooby.l]),
                    .attack_type = .range,
                } },
            },
            .{
                .c = World.Collider{
                    .pos = @Vector(2, f32){ 300, 700 },
                    .vel = @splat(0),
                    .hitbox = @splat(30),
                    .centerpoint = @splat(15),
                },
                .hp = 100,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.animation(u3).init(0.3, textures[Textures.sprite.enemies.blooby.s .. Textures.sprite.enemies.blooby.s + Textures.sprite.enemies.blooby.l]),
                    .attack_type = .range,
                } },
            },
            .{
                .c = World.Collider{
                    .pos = @Vector(2, f32){ 500, 800 },
                    .vel = @splat(0),
                    .hitbox = @splat(30),
                    .centerpoint = @splat(15),
                },
                .hp = 100,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.animation(u3).init(0.3, textures[Textures.sprite.enemies.blooby.s .. Textures.sprite.enemies.blooby.s + Textures.sprite.enemies.blooby.l]),
                    .attack_type = .range,
                } },
            },
            .{
                .c = World.Collider{
                    .pos = @Vector(2, f32){ 800, 300 },
                    .vel = @splat(0),
                    .hitbox = @splat(30),
                    .centerpoint = @splat(15),
                },
                .hp = 100,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.animation(u3).init(0.3, textures[Textures.sprite.enemies.slug.s .. Textures.sprite.enemies.slug.s + Textures.sprite.enemies.slug.l]),
                    .attack_type = .melee,
                } },
            },
            .{
                .c = World.Collider{
                    .pos = @Vector(2, f32){ 700, 600 },
                    .vel = @splat(0),
                    .hitbox = @splat(30),
                    .centerpoint = @splat(15),
                },
                .hp = 100,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.animation(u3).init(0.3, textures[Textures.sprite.enemies.slug.s .. Textures.sprite.enemies.slug.s + Textures.sprite.enemies.slug.l]),
                    .attack_type = .melee,
                } },
            },
        },
    };
    switch (id) {
        1 => {
            self.current_level = Level{ .id = id, .rooms = rooms, .last_room = last_room };
            self.current_room = 0;
        },
        else => {},
    }
}

pub fn nextRoom(self: *Self, textures: []rl.Texture2D) StateError!World {
    if (self.current_level) |level| {
        _ = self.arena.reset(.free_all);
        if (self.current_room < level.last_room) {
            // Commented because for now we just loop through the same room over and over again
            //self.current_room += 1;
            // use the dimensions stored in the level
            var room = try World.init(level.rooms[self.current_room].dimensions, &textures[1], self.arena.allocator());
            try room.addItem(.{ .type = World.WorldPacket.player, .x = 400, .y = 200, .animation = Textures.animation(u2).init(0.5, textures[3..7]) });
            try room.items.appendSlice(&level.rooms[self.current_room].enemies);
            try room.addItem(.{ .type = World.WorldPacket.item, .x = 50, .y = 50, .sprite = &textures[3], .itemtype = .slime, .ammount = 1 });
            return room;
        }
    }
    return StateError.NoLevel;
}
