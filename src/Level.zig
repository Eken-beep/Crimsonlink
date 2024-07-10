const std = @import("std");
const rl = @import("raylib");

const World = @import("World.zig");

const print = std.debug.print;

const LevelGenerationError = error{
    OutOfMemory,
};

pub const Level = struct {
    id: u8,

    rooms: *Room,
};

pub const RoomType = enum {
    Normal,
    Loot,
    Boss,
    Spawn,
};

pub const Direction = enum {
    None,
    North,
    South,
    East,
    West,
};

pub const Room = struct {
    const Self = @This();
    // One of these point to the prevous room
    north: ?*Room,
    south: ?*Room,
    east: ?*Room,
    west: ?*Room,

    room_type: RoomType,
    dimensions: @Vector(2, u16),
    enemies: ?[]World.WorldItem,
    texture: rl.Texture2D,
    completed: bool = false,
    id: u8,

    pub fn printSelf(self: *Self, cameFrom: Direction, depth: u4) void {
        print("depth {d} with {d}\n", .{ depth, self.id });
        if (self.north) |n| {
            if (cameFrom != .North) {
                print("North:", .{});
                printSelf(n, .North, depth + 1);
            }
        }
        if (self.south) |s| {
            if (cameFrom != .South) {
                print("South:", .{});
                printSelf(s, .South, depth + 1);
            }
        }
        if (self.east) |e| {
            if (cameFrom != .East) {
                print("East:", .{});
                printSelf(e, .East, depth + 1);
            }
        }
        if (self.west) |w| {
            if (cameFrom != .West) {
                print("West:", .{});
                printSelf(w, .West, depth + 1);
            }
        }
    }
};

// The room taken as argument here is just a bunch of disconnected nulled ones, gets connected here
pub fn genLevel(allocator: std.mem.Allocator, room_types: []Room) LevelGenerationError!*Room {
    // Room 0, 1, 2 in this list are saved for spawn boss and loot
    // Begin by passing in the first room to the function, spawn is first in the tree
    const seed: u64 = undefined;

    var prng = std.rand.DefaultPrng.init(seed);
    for (room_types) |room| {
        print("{any}\n", .{room.room_type});
    }
    var id: u8 = 0;
    var loot_spawned: f32 = 2;
    var boss_has_spawned: bool = false;
    return try makeRooms(
        allocator,
        room_types[0],
        room_types,
        .None,
        null,
        1,
        prng.random(),
        &id,
        &loot_spawned,
        &boss_has_spawned,
        true,
    );
}

// This sucks, cool idea though
fn makeRooms(
    allocator: std.mem.Allocator,
    room: Room,
    all_rooms: []Room,
    prev_direction: Direction,
    prev_room: ?*Room,
    depth: f16,
    rand: std.Random,
    id: *u8,
    loot_spawned: *f32,
    boss_has_spawned: *bool,
    can_have_children: bool,
) LevelGenerationError!*Room {
    // Reduce the probability of creating a new room by half for each generated room
    const new_depth = depth / 2;
    const return_room = try allocator.create(Room);
    return_room.* = room;
    id.* += 1;
    return_room.*.id = id.*;
    print("Generated room: {d} of type: {any}\n", .{ return_room.*.id, return_room.room_type });
    return_room.*.north = if (prev_direction == .North) prev_room else blk: {
        const room_type = all_rooms[rand.intRangeAtMost(usize, 3, all_rooms.len - 1)];
        if (rand.float(f32) < depth) {
            break :blk try makeRooms(
                allocator,
                room_type,
                all_rooms,
                .South,
                return_room,
                new_depth,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                true,
            );
            // If we encounter the end of a corridor we take a chance at spawning a loot room
        } else if (rand.float(f32) < 1 / loot_spawned.* and can_have_children) {
            loot_spawned.* += 1;
            break :blk try makeRooms(
                allocator,
                // Room [1] is the loot room, no random here
                all_rooms[1],
                all_rooms,
                .South,
                return_room,
                // Set the depth to 0 to guarantee no more normal rooms are spawned
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else if (!boss_has_spawned.* and can_have_children) {
            boss_has_spawned.* = true;
            break :blk try makeRooms(
                allocator,
                // Room [2] is the boss room, no random here
                all_rooms[2],
                all_rooms,
                .South,
                return_room,
                // Set the depth to 0 to guarantee no more loot rooms are spawned
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else break :blk null;
    };
    return_room.*.south = if (prev_direction == .South) prev_room else blk: {
        const room_type = all_rooms[rand.intRangeAtMost(usize, 3, all_rooms.len - 1)];
        if (rand.float(f32) < depth) {
            break :blk try makeRooms(
                allocator,
                room_type,
                all_rooms,
                .North,
                return_room,
                new_depth,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                true,
            );
        } else if (rand.float(f32) < 1 / loot_spawned.* and can_have_children) {
            loot_spawned.* += 1;
            break :blk try makeRooms(
                allocator,
                all_rooms[1],
                all_rooms,
                .North,
                return_room,
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else if (!boss_has_spawned.* and can_have_children) {
            boss_has_spawned.* = true;
            break :blk try makeRooms(
                allocator,
                all_rooms[2],
                all_rooms,
                .North,
                return_room,
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else break :blk null;
    };
    return_room.*.east = if (prev_direction == .East) prev_room else blk: {
        const room_type = all_rooms[rand.intRangeAtMost(usize, 3, all_rooms.len - 1)];
        if (rand.float(f32) < depth) {
            break :blk try makeRooms(
                allocator,
                room_type,
                all_rooms,
                .West,
                return_room,
                new_depth,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                true,
            );
        } else if (rand.float(f32) < 1 / loot_spawned.* and can_have_children) {
            loot_spawned.* += 1;
            break :blk try makeRooms(
                allocator,
                all_rooms[1],
                all_rooms,
                .West,
                return_room,
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else if (!boss_has_spawned.* and can_have_children) {
            boss_has_spawned.* = true;
            break :blk try makeRooms(
                allocator,
                all_rooms[2],
                all_rooms,
                .West,
                return_room,
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else break :blk null;
    };
    return_room.*.west = if (prev_direction == .West) prev_room else blk: {
        const room_type = all_rooms[rand.intRangeAtMost(usize, 3, all_rooms.len - 1)];
        if (rand.float(f32) < depth) {
            break :blk try makeRooms(
                allocator,
                room_type,
                all_rooms,
                .East,
                return_room,
                new_depth,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                true,
            );
        } else if (rand.float(f32) < 1 / loot_spawned.* and can_have_children) {
            loot_spawned.* += 1;
            break :blk try makeRooms(
                allocator,
                all_rooms[1],
                all_rooms,
                .East,
                return_room,
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else if (!boss_has_spawned.* and can_have_children) {
            boss_has_spawned.* = true;
            break :blk try makeRooms(
                allocator,
                all_rooms[2],
                all_rooms,
                .East,
                return_room,
                0,
                rand,
                id,
                loot_spawned,
                boss_has_spawned,
                false,
            );
        } else break :blk null;
    };

    return return_room;
}
