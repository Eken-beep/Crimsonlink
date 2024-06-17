const std = @import("std");
const World = @import("World.zig");
const Textures = @import("Textures.zig");

const EnemyPackage = struct {
    width: f16,
    height: f16,
    hp: u8,
    animation: [2]usize,
    attack_type: u8,
};

const enemyClassError = error{NonImplementedEnemy};
pub fn mapClassToType(enemyclass: []const u8) enemyClassError!EnemyPackage {
    if (std.mem.eql(u8, "blooby", enemyclass)) {
        return EnemyPackage{
            .width = 50,
            .height = 50,
            .hp = 50,
            .animation = Textures.getImageId("blooby"),
            .attack_type = 1,
        };
    } else if (std.mem.eql(u8, "slug", enemyclass)) {
        return EnemyPackage{
            .width = 50,
            .height = 50,
            .hp = 150,
            .animation = Textures.getImageId("slug"),
            .attack_type = 2,
        };
    } else return enemyClassError.NonImplementedEnemy;
}
