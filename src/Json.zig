const std = @import("std");
const SDL = @import("sdl2");

const Player = @import("Player.zig");
const World = @import("World.zig");
const Statemanager = @import("Statemanager.zig");
const CsvParser = @import("CsvParser.zig");
const Textures = @import("Textures.zig");
const Input = @import("Input.zig");
const Items = @import("Items.zig");
const Level = @import("Level.zig");
const Bitmap = @import("Bitmap.zig");

const DefaultPlayerData = @embedFile("datapresets/StandardPlayer.json");
const DefaultKeybinds = @embedFile("datapresets/DefaultBindings.json");

const json = std.json;

const ConfigurationError = error{
    OutOfMemory,
    FailedToAccessConfig,
    FailedToAccessRoomData,
    FailedToAccessLevelData,
    JsonParseError,
    InvalidKeybindingConfig,
    InvalidPlayerdataFile,
    InvalidMapdataFile,
    EnemyDoesNotExist,

    SdlError,
};

pub fn loadPlayerData(
    file: ?[]const u8,
    allocator: std.mem.Allocator,
    textures: Textures.TextureMap,
) ConfigurationError!Player {
    const RawPlayerData = struct {
        hp: u8,
        max_hp: u8,
        damage: u8,
        dogecoins: u10,
    };
    const parsed = std.json.parseFromSlice(
        RawPlayerData,
        allocator,
        file orelse DefaultPlayerData,
        .{},
    ) catch return ConfigurationError.JsonParseError;
    const v = parsed.value;
    return Player{
        .hp = v.hp,
        .max_hp = v.max_hp,
        .damage = v.damage,
        .hand_placement = @Vector(2, f32){ 10, 10 },
        .forehand = blk: {
            var tmp = for (Items.Weapons) |weapon| {
                if (std.mem.eql(u8, weapon.name, "Gun")) break weapon;
            } else Items.Weapons[0];
            tmp.texture = Textures.getTexture(textures, tmp.name).slice[0];

            break :blk tmp;
        },
        .inventory = .{
            .dogecoins = v.dogecoins,
            .items = [4]?Player.Item{ null, null, null, Player.Item{
                .ammount = 5,
                .type = .slime,
                .image = Textures.getTexture(textures, "slime").single,
            } },
        },
    };
}

// Inconsistent with the other loading functions who use a return instead of pointer
pub fn loadKeybindings(
    configfile: ?[]const u8,
    keybindings: *std.AutoHashMap(i10, Input.InputAction),
    allocator: std.mem.Allocator,
) ConfigurationError!void {
    const parsed = json.parseFromSlice(
        json.Value,
        allocator,
        configfile orelse DefaultKeybinds,
        .{},
    ) catch return ConfigurationError.JsonParseError;
    const keyarray = parsed.value.array.items;
    for (keyarray) |keybindobject| {
        const bind = keybindobject.object.get("key") orelse return ConfigurationError.InvalidKeybindingConfig;
        const action = keybindobject.object.get("action") orelse return ConfigurationError.InvalidKeybindingConfig;
        try keybindings.put(@as(i10, @intCast(bind.integer)), try mapActionToInputAction(action.string));
    }
}

const IntermediaryEnemyRepresentation = struct {
    enemytype: []const u8,
    x: f64,
    y: f64,
};

pub fn getLevel(
    r: *SDL.Renderer,
    level_id: u8,
    allocator: std.mem.Allocator,
    textures: Textures.TextureMap,
) ConfigurationError!Level.Level {
    const leveldata_path: []const u8 = try std.fmt.allocPrint(allocator, "data/levels/{d}/level.json", .{level_id});
    const raw_leveldata = std.fs.cwd().readFileAlloc(
        allocator,
        leveldata_path,
        @as(usize, @intFromFloat(@exp2(20.0))),
    ) catch return ConfigurationError.FailedToAccessLevelData;
    const parsed_leveldata = json.parseFromSlice(
        json.Value,
        allocator,
        raw_leveldata,
        .{},
    ) catch return ConfigurationError.JsonParseError;
    const nr_rooms: u8 = @intCast(parsed_leveldata.value.object.get("rooms").?.integer);

    const rooms = try allocator.alloc(Level.Room, nr_rooms);
    for (rooms, 0..) |_, i| {
        const id: u8 = @intCast(i);
        rooms[i] = try loadRoom(r, level_id, id, allocator, textures);
    }
    return Level.Level{
        .id = level_id,
        .rooms = try Level.genLevel(allocator, rooms),
    };
}

fn loadRoom(
    r: *SDL.Renderer,
    level_id: u8,
    room_id: u8,
    allocator: std.mem.Allocator,
    textures: Textures.TextureMap,
) ConfigurationError!Level.Room {
    // TODO
    // change this to load the file from some useful place OR embed the data files that shouldn't change
    const room_file_path: [:0]const u8 = try std.fmt.allocPrintZ(allocator, "data/levels/{d}/room_{d}.json", .{ level_id, room_id });
    const room_texture_filename: [:0]const u8 = try std.fmt.allocPrintZ(allocator, "data/levels/{d}/room_{d}.bmp", .{ level_id, room_id });
    const room_file_raw = std.fs.cwd().readFileAlloc(
        allocator,
        room_file_path,
        @as(usize, @intFromFloat(@exp2(20.0))),
    ) catch return ConfigurationError.FailedToAccessRoomData;
    const parsed = json.parseFromSlice(
        json.Value,
        allocator,
        room_file_raw,
        .{},
    ) catch return ConfigurationError.JsonParseError;

    var ret: Level.Room = undefined;

    const width: u16 = @intCast(parsed.value.object.get("width").?.integer);
    const height: u16 = @intCast(parsed.value.object.get("height").?.integer);
    ret.dimensions = @Vector(2, u16){ width, height };
    // This is technically a memory leak, I think
    // We need to destroy this image after the level is unloaded to fix this
    const surface = try SDL.loadBmp(room_texture_filename);
    ret.texture = try SDL.createTextureFromSurface(r.*, surface);

    ret.walls = try Bitmap.getTransparentAreas(allocator, surface);

    ret.room_type = try mapRoomtypeToEnum(parsed.value.object.get("roomtype").?.string);

    const enemies_nullable = parsed.value.object.get("enemies");

    ret.enemies = if (enemies_nullable) |e| blk: {
        const enemies = e.array.items;
        var enemy_buffer = try allocator.alloc(World.WorldItem, enemies.len);
        for (enemies, 0..) |raw_enemy, i| {
            const enemy_data = CsvParser.mapClassToType(raw_enemy.object.get("type").?.string) catch return ConfigurationError.InvalidMapdataFile;
            enemy_buffer[i] = World.WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){
                        @floatFromInt(raw_enemy.object.get("x").?.integer),
                        @floatFromInt(raw_enemy.object.get("y").?.integer),
                    },
                    .centerpoint = @Vector(2, f16){ enemy_data.width * 2, enemy_data.height * 2 },
                    .hitbox = @Vector(2, f16){ enemy_data.width * 4, enemy_data.height * 4 },
                    .render_width = @as(u16, @intFromFloat(enemy_data.width)) * 4,
                    .render_height = @as(u16, @intFromFloat(enemy_data.height)) * 4,
                    .vel = @splat(0),
                    .flags = .{
                        .kinetic = true,
                        .transparent = false,
                    },
                    .texture_offset = @splat(0),
                },
                .hp = enemy_data.hp,
                .meta = World.WorldItemMetadata{ .enemy = .{
                    .animation = Textures.Animation{
                        .nr_frames = 8,
                        .frametime = 0.2,
                        .avalilable_directions = 1,
                        .frames = bll: {
                            const framebuffer = try allocator.alloc(Textures.AnimationData, 1);
                            std.debug.print("{s}\n", .{enemy_data.name});
                            framebuffer[0] = Textures.AnimationData.init(enemy_data.name, textures);
                            break :bll framebuffer;
                        },
                    },
                    .type = try mapNameToEnemytype(enemy_data.name),
                    .attack_type = @enumFromInt(enemy_data.attack_type),
                    .damage = enemy_data.damage,
                    .score_bonus = enemy_data.score_bonus,
                } },
            };
        }
        break :blk enemy_buffer;
    } else null;
    return ret;
}

fn mapActionToInputAction(action: []const u8) ConfigurationError!Input.InputAction {
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
    return ConfigurationError.InvalidMapdataFile;
}

fn mapRoomtypeToEnum(roomtype: []const u8) ConfigurationError!Level.RoomType {
    if (std.mem.eql(u8, "normal", roomtype)) return Level.RoomType.Normal;
    if (std.mem.eql(u8, "spawn", roomtype)) return Level.RoomType.Spawn;
    if (std.mem.eql(u8, "loot", roomtype)) return Level.RoomType.Loot;
    if (std.mem.eql(u8, "boss", roomtype)) return Level.RoomType.Boss;
    return ConfigurationError.InvalidMapdataFile;
}

fn mapNameToEnemytype(et: []const u8) ConfigurationError!World.EnemyType {
    if (std.mem.eql(u8, "blooby", et)) return World.EnemyType.blooby;
    if (std.mem.eql(u8, "slug", et)) return World.EnemyType.slug;
    return ConfigurationError.EnemyDoesNotExist;
}
