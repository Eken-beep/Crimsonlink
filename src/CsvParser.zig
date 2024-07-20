const std = @import("std");
const World = @import("World.zig");

const enemies_raw = @embedFile("datapresets/enemies.csv");
const weapons_raw = @embedFile("datapresets/weapons.csv");

// Ignore last line
const nr_enemy_types = std.mem.count(u8, enemies_raw, "\n") - 1;
const nr_weapons = std.mem.count(u8, weapons_raw, "\n") - 1;

const EnemyPackage = struct {
    name: []const u8,
    width: f16,
    height: f16,
    damage: u16,
    hp: u8,
    attack_type: u8,
    score_bonus: u32,
};

const WeaponPackage = struct {
    name: []const u8,
    handle: @Vector(2, f16),
    damage: u16,
    range: u8,
};

const enemyClassError = error{NonImplementedEnemy};
pub fn mapClassToType(enemyclass: []const u8) enemyClassError!EnemyPackage {
    for (comptime makeEnemyData() catch @compileError("Invalid enemydata file")) |enemy_data| {
        if (std.mem.eql(u8, enemyclass, enemy_data.name)) {
            return enemy_data;
        }
    } else return enemyClassError.NonImplementedEnemy;
}

fn makeEnemyData() std.fmt.ParseIntError![nr_enemy_types]EnemyPackage {
    comptime var result: [nr_enemy_types]EnemyPackage = undefined;
    comptime var iterator = std.mem.splitScalar(u8, enemies_raw, '\n');
    comptime var i = 0;
    _ = iterator.next();
    inline while (iterator.next()) |data| : (i += 1) {
        if (data.len == 0) continue; // Skip the last empty line some spreadsheets leave behind in csv files
        const unprocessed = getOneDataline(7, data);
        result[i] = EnemyPackage{
            .name = unprocessed[0],
            .width = @floatFromInt(try std.fmt.parseInt(u15, unprocessed[1], 10)),
            .height = @floatFromInt(try std.fmt.parseInt(u15, unprocessed[2], 10)),
            .damage = try std.fmt.parseInt(u16, unprocessed[3], 10),
            .score_bonus = try std.fmt.parseInt(u32, unprocessed[4], 10),
            .hp = try std.fmt.parseInt(u8, unprocessed[5], 10),
            .attack_type = if (std.mem.eql(u8, "range", unprocessed[6])) 1 else if (std.mem.eql(u8, "melee", unprocessed[6])) 2 else {
                @compileError("Incorrect enemydata file: " ++ data);
            },
        };
    }

    return result;
}

pub fn makeWeapons() [nr_weapons]WeaponPackage {
    comptime var result: [nr_weapons]WeaponPackage = undefined;
    comptime var iterator = std.mem.splitScalar(u8, weapons_raw, '\n');
    comptime var i = 0;
    _ = iterator.next();
    inline while (iterator.next()) |data| : (i += 1) {
        if (data.len == 0) continue; // Skip the last empty line some spreadsheets leave behind in csv files
        const unprocessed = getOneDataline(5, data);
        result[i] = WeaponPackage{
            .name = unprocessed[0],
            .handle = @Vector(2, f16){
                @as(f16, @floatFromInt(std.fmt.parseInt(u16, unprocessed[1], 10) catch @compileError("Invalid weapondata file: " ++ data))),
                @as(f16, @floatFromInt(std.fmt.parseInt(u16, unprocessed[2], 10) catch @compileError("Invalid weapondata file: " ++ data))),
            },
            .damage = std.fmt.parseInt(u16, unprocessed[3], 10) catch @compileError("Invalid weapondata file: " ++ data),
            .range = if (std.mem.eql(u8, "range", unprocessed[4])) 1 else if (std.mem.eql(u8, "melee", unprocessed[5])) 2 else {
                @compileError("Invalid weapondata file: " ++ data);
            },
        };
    }

    return result;
}

fn getOneDataline(comptime n: usize, data: []const u8) [n][]const u8 {
    comptime var result: [n][]const u8 = undefined;
    comptime var datapoints: usize = 0;
    comptime var tail: usize = 0;
    inline for (data, 0..) |c, i| {
        if ((c == ',' and i != tail)) {
            result[datapoints] = data[tail..i];
            datapoints += 1;
            tail = i + 1;
        } else if (i == data.len - 1) {
            result[result.len - 1] = data[tail .. i + 1];
            return result;
        }
    }
    @compileError("Incorrect enemydata file" ++ data);
}

test "Enemy data file" {
    const test_data = comptime makeEnemyData() catch |err| switch (err) {
        std.fmt.ParseIntError.InvalidCharacter => @compileError(enemies_raw),
        else => return err,
    };
    try std.testing.expect(std.mem.eql(u8, test_data[0].name, "blooby"));
}
