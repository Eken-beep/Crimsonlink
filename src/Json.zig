const std = @import("std");
const rl = @import("raylib");
const Player = @import("Player.zig");
const World = @import("World.zig");
const Statemanager = @import("Statemanager.zig");
const EnemyTypes = @import("EnemyTypes.zig");
const Textures = @import("Textures.zig");
const Input = @import("Input.zig");
const Items = @import("Items.zig");
const Level = @import("Level.zig");

const DefaultPlayerData = @embedFile("datapresets/StandardPlayer.json");
const DefaultKeybinds = @embedFile("datapresets/DefaultBindings.json");

const json = std.json;

pub fn loadPlayerData(file: ?[]const u8, allocator: std.mem.Allocator, textures: Textures.TextureMap) !Player {
    const RawPlayerData = struct {
        hp: u8,
        max_hp: u8,
        damage: u8,
        dogecoins: u10,
    };
    const parsed = try std.json.parseFromSlice(
        RawPlayerData,
        allocator,
        file orelse DefaultPlayerData,
        .{},
    );
    const v = parsed.value;
    return Player{
        .hp = v.hp,
        .max_hp = v.max_hp,
        .damage = v.damage,
        .hand_placement = @Vector(2, f32){ 10, 10 },
        .forehand = blk: {
            var tmp = Items.Weapons.Gun1;
            tmp.texture = Textures.getTexture(textures, "Gun").slice[0];

            break :blk tmp;
        },
        .inventory = .{ .dogecoins = v.dogecoins, .items = [1]?Player.Item{null} ** 10 },
    };
}

const ConfigParseError = error{InvalidKeyConfig};
// Inconsistent with the other loading functions who use a return instead of pointer
pub fn loadKeybindings(
    configfile: ?[]const u8,
    keybindings: *std.AutoHashMap(i10, Input.InputAction),
    allocator: std.mem.Allocator,
) !void {
    const parsed = try json.parseFromSlice(json.Value, allocator, configfile orelse DefaultKeybinds, .{});
    const keyarray = parsed.value.array.items;
    for (keyarray) |keybindobject| {
        const bind = keybindobject.object.get("key") orelse return ConfigParseError.InvalidKeyConfig;
        const action = keybindobject.object.get("action") orelse return ConfigParseError.InvalidKeyConfig;
        try keybindings.put(@as(i10, @intCast(bind.integer)), try mapActionToInputAction(action.string));
    }
}

const IntermediaryEnemyRepresentation = struct {
    enemytype: []const u8,
    x: f64,
    y: f64,
};

pub fn getLevel(level_id: u8, allocator: std.mem.Allocator, textures: std.StringArrayHashMap(Textures.TextureStore)) anyerror!Level.Level {
    const leveldata_path: []const u8 = try std.fmt.allocPrint(allocator, "data/levels/{d}/level.json", .{level_id});
    const raw_leveldata = try std.fs.cwd().readFileAlloc(allocator, leveldata_path, @as(usize, @intFromFloat(@exp2(20.0))));
    const parsed_leveldata = try json.parseFromSlice(json.Value, allocator, raw_leveldata, .{});
    const nr_rooms: u8 = @intCast(parsed_leveldata.value.object.get("rooms").?.integer);

    const rooms = try allocator.alloc(Level.Room, nr_rooms);
    for (rooms, 0..) |_, i| {
        const id: u8 = @intCast(i);
        rooms[i] = try loadRoom(level_id, id, allocator, textures);
    }
    return Level.Level{
        .id = level_id,
        .rooms = try Level.genLevel(allocator, rooms),
    };
}

fn loadRoom(level_id: u8, room_id: u8, allocator: std.mem.Allocator, textures: std.StringArrayHashMap(Textures.TextureStore)) anyerror!Level.Room {
    // TODO
    // change this to load the file from some useful place OR embed the data files that shouldn't change
    const room_file_path: [:0]const u8 = try std.fmt.allocPrintZ(allocator, "data/levels/{d}/room_{d}.json", .{ level_id, room_id });
    const room_texture_filename: [:0]const u8 = try std.fmt.allocPrintZ(allocator, "data/levels/{d}/room_{d}.png", .{ level_id, room_id });
    const room_file_raw = try std.fs.cwd().readFileAlloc(allocator, room_file_path, @as(usize, @intFromFloat(@exp2(20.0))));
    const parsed = try json.parseFromSlice(
        json.Value,
        allocator,
        room_file_raw,
        .{},
    );

    var ret: Level.Room = undefined;

    const width: u16 = @intCast(parsed.value.object.get("width").?.integer);
    const height: u16 = @intCast(parsed.value.object.get("height").?.integer);
    ret.dimensions = @Vector(2, u16){ width, height };
    // This is technically a memory leak, I think
    ret.texture = rl.loadTextureFromImage(rl.loadImage(room_texture_filename));

    ret.room_type = try mapRoomtypeToEnum(parsed.value.object.get("roomtype").?.string);

    const enemies_nullable = parsed.value.object.get("enemies");

    ret.enemies = if (enemies_nullable) |e| blk: {
        const enemies = e.array.items;
        var enemy_buffer = try allocator.alloc(World.WorldItem, enemies.len);
        for (enemies, 0..) |raw_enemy, i| {
            const enemy_data = try EnemyTypes.mapClassToType(raw_enemy.object.get("type").?.string);
            enemy_buffer[i] = World.WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){
                        @floatFromInt(raw_enemy.object.get("x").?.integer),
                        @floatFromInt(raw_enemy.object.get("y").?.integer),
                    },
                    .centerpoint = @Vector(2, f16){ enemy_data.width / 2, enemy_data.height / 2 },
                    .hitbox = @Vector(2, f16){ enemy_data.width, enemy_data.height },
                    .vel = @splat(0),
                    .collision = .kinetic,
                    .texture_offset = @splat(0),
                },
                .hp = enemy_data.hp,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.Animation{
                        .nr_frames = 8,
                        .frametime = 0.2,
                        .avalilable_directions = 1,
                        .frames = bll: {
                            const framebuffer = try allocator.alloc([]rl.Texture2D, 1);
                            framebuffer[0] = Textures.getTextures(textures, enemy_data.animation_name).slice;
                            break :bll framebuffer;
                        },
                    },
                    .attack_type = @enumFromInt(enemy_data.attack_type),
                } },
            };
        }
        break :blk enemy_buffer;
    } else null;
    return ret;
}

fn mapActionToInputAction(action: []const u8) !Input.InputAction {
    // This abomination is zig fmt's fault
    if (std.mem.eql(u8, "moveup", action)) return Input.InputAction.moveup;
    if (std.mem.eql(u8, "moveleft", action)) return Input.InputAction.moveleft;
    if (std.mem.eql(u8, "movedown", action)) return Input.InputAction.movedown;
    if (std.mem.eql(u8, "moveright", action)) return Input.InputAction.moveright;
    if (std.mem.eql(u8, "haltup", action)) return Input.InputAction.haltup;
    if (std.mem.eql(u8, "haltleft", action)) return Input.InputAction.haltleft;
    if (std.mem.eql(u8, "haltdown", action)) return Input.InputAction.haltdown;
    if (std.mem.eql(u8, "haltright", action)) return Input.InputAction.haltright;
    if (std.mem.eql(u8, "shoot_begin", action)) return Input.InputAction.shoot_begin;
    if (std.mem.eql(u8, "shoot_end", action)) return Input.InputAction.shoot_end;
    if (std.mem.eql(u8, "pause", action)) return Input.InputAction.pause;
    return error.InvalidKeyConfig;
}

fn mapRoomtypeToEnum(roomtype: []const u8) !Level.RoomType {
    if (std.mem.eql(u8, "normal", roomtype)) return Level.RoomType.Normal;
    if (std.mem.eql(u8, "spawn", roomtype)) return Level.RoomType.Spawn;
    if (std.mem.eql(u8, "loot", roomtype)) return Level.RoomType.Loot;
    if (std.mem.eql(u8, "boss", roomtype)) return Level.RoomType.Boss;
    return error.InvalidMapData;
}
