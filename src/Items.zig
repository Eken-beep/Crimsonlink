const std = @import("std");
const rl = @import("raylib");
const Collider = @import("Collider.zig");
const World = @import("World.zig");
const CsvParser = @import("CsvParser.zig");

pub const Weapon = struct {
    // Where on the gun is the handle? Anchored to the gun itself
    handle: @Vector(2, f16),
    range: WeaponRange,
    texture: rl.Texture2D,
    name: []const u8,
};

const WeaponRange = union(enum) {
    melee: struct {
        const Self = @This();
        damage: u16,
        range: f16,
        // How many radians on each side of the attack angle the weapon reaches
        angle: f16,
        slice_animation: rl.Texture2D,
    },
    range: struct {
        damage: u16,
        bullet_texture: rl.Texture2D,
    },
};

// This function is just chilling here even though it should really be somewhere else
pub fn makeBullet(
    gun: Weapon,
    owner: World.WorldItem,
    cursor: @Vector(2, f32),
    window_origin: @Vector(2, f32),
    window_scale: f32,
) World.WorldItem {
    const weaponw: f32 = @floatFromInt(4 * gun.texture.width);
    const weaponh: f32 = @floatFromInt(4 * gun.texture.height);
    const weaponx = owner.c.pos[0] + owner.c.weapon_mount.?[0] - gun.handle[0];
    const weapony = owner.c.pos[1] + owner.c.weapon_mount.?[1] - gun.handle[0];
    const angle = std.math.atan2(
        weapony + weaponh / 2 - (cursor[1] - window_origin[1]) / window_scale,
        weaponx + weaponw - (cursor[0] - window_origin[0]) / window_scale,
    );
    return World.WorldItem{
        .hp = 1,
        .c = .{
            .pos = @Vector(2, f32){
                weaponx + weaponw,
                weapony + weaponh / 2,
            },
            .vel = @Vector(2, f32){ @cos(angle) * -1000, @sin(angle) * -1000 },
            .flags = .{
                .kinetic = true,
                .transparent = true,
            },
            .centerpoint = @splat(5),
            .effect = @splat(0),
            .hitbox = @splat(10),
            .texture_offset = @splat(5),
        },
        .meta = .{ .bullet = .{
            .damage = gun.range.range.damage,
            .owner = switch (owner.meta) {
                .player => .player,
                .enemy => .enemy,
                else => unreachable,
            },
        } },
    };
}

pub const Weapons = blk: {
    const raw = CsvParser.makeWeapons();
    var result: [raw.len]Weapon = undefined;
    for (raw, 0..) |raw_weapon, i| {
        result[i] = Weapon{
            .name = raw_weapon.name,
            .handle = raw_weapon.handle,
            .range = switch (raw_weapon.range) {
                1 => WeaponRange{ .range = .{
                    .bullet_texture = undefined,
                    .damage = raw_weapon.damage,
                } },
                2 => unreachable,
                else => unreachable,
            },
            .texture = undefined,
        };
    }
    break :blk result;
};
