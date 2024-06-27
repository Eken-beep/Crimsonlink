const std = @import("std");
const rl = @import("raylib");
const Player = @import("Player.zig");
const World = @import("World.zig");
const Statemanager = @import("Statemanager.zig");
const EnemyTypes = @import("EnemyTypes.zig");
const Textures = @import("Textures.zig");
const Input = @import("Input.zig");
const Items = @import("Items.zig");

const DefaultPlayerData = @embedFile("datapresets/StandardPlayer.json");
const DefaultKeybinds = @embedFile("datapresets/DefaultBindings.json");

const json = std.json;

pub fn loadPlayerData(file: ?[]const u8, allocator: std.mem.Allocator, textures: []rl.Texture2D) !Player {
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
            tmp.texture = &textures[Textures.getImageId(Items.Weapons.Gun1.name)[0]];

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

pub fn loadRoom(level_id: u8, room_id: u8, allocator: std.mem.Allocator, textures: []rl.Texture2D) anyerror!Statemanager.Room {
    // TODO
    // change this to load the file from some useful place OR embed the data files that shouldn't change like this one
    const room_file_path: [:0]const u8 = try std.fmt.allocPrintZ(allocator, "data/levels/{d}/room_{d}.json", .{ level_id, room_id });
    const room_file_raw = try std.fs.cwd().readFileAlloc(allocator, room_file_path, @as(usize, @intFromFloat(@exp2(20.0))));
    const parsed = try json.parseFromSlice(
        json.Value,
        allocator,
        room_file_raw,
        .{},
    );

    var ret: Statemanager.Room = undefined;

    const width: u16 = @intCast(parsed.value.object.get("width").?.integer);
    const height: u16 = @intCast(parsed.value.object.get("height").?.integer);
    ret.dimensions = @Vector(2, u16){ width, height };
    ret.texture = &textures[Textures.getImageId("standard_W1")[0]];

    // The enemies always have to be on the second layer
    const enemies = parsed.value.object.get("enemies").?.array.items;

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
                .animation = Textures.animation(u3).init(0.2, textures[enemy_data.animation[0]..enemy_data.animation[1]]),
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
