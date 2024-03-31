const std = @import("std");
const rl = @import("raylib");
const Player = @import("Player.zig");
const World = @import("World.zig");
const Statemanager = @import("Statemanager.zig");
const EnemyTypes = @import("EnemyTypes.zig");
const Textures = @import("Textures.zig");

const DefaultPlayerData = @embedFile("data/StandardPlayer.json");

const json = std.json;

pub fn loadPlayerData(file: ?[]const u8, allocator: std.mem.Allocator) !Player {
    const RawPlayerData = struct {
        hp: u8,
        max_hp: u8,
        damage: u8,
        dogecoins: u32,
    };
    const parsed = try std.json.parseFromSlice(
        RawPlayerData,
        allocator,
        file orelse DefaultPlayerData,
        .{},
    );
    const v = parsed.value;
    return Player{ .hp = v.hp, .max_hp = v.max_hp, .damage = v.damage, .inventory = .{ .dogecoins = v.dogecoins, .items = undefined } };
}

const IntermediaryEnemyRepresentation = struct {
    enemytype: []const u8,
    x: f64,
    y: f64,
};

pub fn loadRoom(level_id: u8, room_id: u8, allocator: std.mem.Allocator, textures: []rl.Texture2D) anyerror!Statemanager.Room {
    // TODO
    // change this to load the file from some useful place OR embed the data files that shouldn't change like this one
    const room_file_path: [:0]const u8 = try std.fmt.allocPrintZ(allocator, "src/data/levels/{d}/room_{d}.json", .{ level_id, room_id });
    const room_file_raw = try std.fs.cwd().readFileAlloc(allocator, room_file_path, @as(usize, @intFromFloat(@exp2(20.0))));
    const parsed = try json.parseFromSlice(
        json.Value,
        allocator,
        room_file_raw,
        .{},
    );

    var ret: Statemanager.Room = undefined;

    const tilesize = parsed.value.object.get("tileheight").?.integer;
    const width: u16 = @intCast(parsed.value.object.get("width").?.integer * tilesize);
    const height: u16 = @intCast(parsed.value.object.get("height").?.integer * tilesize);
    ret.dimensions = @Vector(2, u16){ width, height };

    // The enemies always have to be on the second layer
    const enemies = parsed.value.object.get("layers").?.array.items[1].object.get("objects").?.array.items;

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
            },
            .hp = enemy_data.hp,
            .meta = World.WorldItemMetadata{ .enemy = .{
                .animation = Textures.animation(u3).init(0.2, textures[enemy_data.animation.s .. enemy_data.animation.s + enemy_data.animation.l]),
                .attack_type = @enumFromInt(enemy_data.attack_type),
            } },
        };
    }
    ret.enemies = enemy_buffer;
    return ret;
}

fn processEnemies(allocator: std.mem.Allocator, enemies: []json.Value.objectMap) []IntermediaryEnemyRepresentation {
    var buffer = allocator.alloc(IntermediaryEnemyRepresentation, enemies.items.len);
    for (enemies.items, 0..) |enemy, i| {
        buffer[i] = IntermediaryEnemyRepresentation{
            .enemytype = enemy.get("type").?.string,
            .x = enemy.get("x").?.float,
            .y = enemy.get("y").?.float,
        };
    }
}