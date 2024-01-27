const std = @import("std");
const World = @import("World");

const Self = @This();

// Public declarations //
hp: i16 = 100,
max_hp: i16 = 100,
level: u8 = 0,

// Private declarations
var stats = struct {
    .movementspeed = 10,
    .strength = 5,
};

pub fn addHp(self: *Self, hp: i16) void {
    self.hp = @min(self.max_hp, self.hp + hp);
}

//pub fn shoot(self: *Self) World.CollisionItem;
