const std = @import("std");
const rl = @import("raylib");
const Textures = @import("Textures.zig");
const Self = @This();

// The world stores all things that are temporary and resets when the room does
// also handles things related to that such as moving items and enemy ai;s
pub const CollisionType = enum { Player, Bullet, Enemy, Wall };

pub const Hitbox = union(enum) { radius: f32, rectangle: @Vector(2, f32) };

// Definitions for an item in the world looks like:
// world object:
//   collider:
//     hitbox: circle | rectangle
//     position
//   meta:
//     union of bullet or player or enemy

pub const WorldObject = struct { c: Collider, meta: ObjectMetadata };

pub const Collider = struct {
    pos: @Vector(2, f32),
    hitbox: Hitbox,
};
// While the collider is generic for everything that can be in the world, we have this field for everything else
pub const ObjectMetadata = union(enum) {
    player: Player,
    bullet: Bullet,
    enemy: Enemy,
};

const Player = struct {
    sprite: *rl.Texture2D,
};
const Bullet = struct {
    color: rl.Color,
    velocity: @Vector(2, f32),
    damage: u8,
};
const Enemy = struct {
    sprite: *rl.Texture2D,
    // why is this even a u8
    hp: u8,
};

allocator: std.mem.Allocator,
items: std.ArrayList(WorldObject),
textures: []rl.Texture2D,
width: u16,
height: u16,

pub fn init(alloc: std.mem.Allocator, width: u16, height: u16, images: []rl.Image) !Self {
    var t = try alloc.alloc(rl.Texture2D, Textures.all_images.len);
    for (0..Textures.all_images.len) |i| {
        t[i] = rl.loadTextureFromImage(images[i]);
    }
    return Self{
        .allocator = alloc,
        .items = std.ArrayList(WorldObject).init(alloc),
        .textures = t,
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: *Self) void {
    self.items.deinit();
    for (0..Textures.all_images.len) |i| {
        rl.unloadTexture(self.textures[i]);
    }
    self.allocator.free(self.textures);
}

pub fn addItem(self: *Self, ctype: CollisionType, x: f32, y: f32, hitbox: Hitbox, image: ?*rl.Texture2D, velocity: @Vector(2, f32)) !void {
    const meta: ObjectMetadata = switch (ctype) {
        .Bullet => ObjectMetadata{ .bullet = Bullet{ .color = rl.Color.magenta, .velocity = velocity, .damage = 10 } },
        // TODO actually return an error if an image is needed
        .Player => ObjectMetadata{ .player = Player{ .sprite = if (image) |img| img else return } },
        .Enemy => ObjectMetadata{ .enemy = Enemy{ .sprite = if (image) |img| img else return, .hp = 100 } },
        else => return,
    };
    try self.items.append(WorldObject{ .c = Collider{ .pos = @Vector(2, f32){ x, y }, .hitbox = hitbox }, .meta = meta });
}

pub fn moveItem(self: *Self, i: *Self.WorldObject, to: @Vector(2, f32)) void {
    var goal = i.c.pos + to;
    const fw: f32 = @floatFromInt(self.width);
    const fh: f32 = @floatFromInt(self.height);
    const hitbox: @Vector(2, f32) = blk: {
        const hb = i.c.hitbox;
        switch (hb) {
            .radius => |r| break :blk @Vector(2, f32){ r, r },
            .rectangle => |r| break :blk r,
        }
    };
    // we just make sure that the moved item doesn't go out of bounds, other collision handled elsewhere
    if (goal[0] + hitbox[0] > fw) goal[0] = fw - hitbox[0] else if (goal[0] - hitbox[0] < 0) goal[0] = hitbox[0];
    if (goal[1] + hitbox[1] > fh) goal[1] = fh - hitbox[0] else if (goal[1] - hitbox[0] < 0) goal[1] = hitbox[0];
    i.c.pos = goal;
}

pub fn stepMovement(self: *Self) void {
    const world_width: f32 = @floatFromInt(self.width);
    const world_height: f32 = @floatFromInt(self.height);
    var len: usize = self.items.items.len;
    var i: usize = 0;
    // This is a while loop because if an item is being removed we get an oob error with the array when using a for loop
    while (i < len) : (i += 1) {
        const item = self.items.items[i];
        // If we want to update some other thing later on
        switch (item.meta) {
            .bullet => {
                if (item.c.pos[0] > world_width or item.c.pos[0] < 0 or item.c.pos[1] > world_height or item.c.pos[1] < 0) {
                    _ = self.items.orderedRemove(i);
                    len -= 1;
                } else {
                    const dt: f32 = rl.getFrameTime();
                    const v = @Vector(2, f32){ item.meta.bullet.velocity[0] * dt, item.meta.bullet.velocity[1] * dt };
                    self.items.items[i].c.pos += v;
                    for (self.items.items, 0..) |collision_compare, j| {
                        if (collision_compare.meta == .enemy) {
                            const dx: f32 = collision_compare.c.pos[0] - item.c.pos[0];
                            const dy: f32 = collision_compare.c.pos[1] - item.c.pos[1];
                            if (@sqrt(dx * dx - dy * dy) < collision_compare.c.hitbox.radius + item.c.hitbox.radius) {
                                self.items.items[j].meta.enemy.hp = blk: {
                                    if (item.meta.bullet.damage > collision_compare.meta.enemy.hp) {
                                        std.debug.print("enemy down!! {d}", .{item.meta.bullet.damage});
                                        break :blk 0;
                                    } else break :blk collision_compare.meta.enemy.hp - item.meta.bullet.damage;
                                    std.debug.print("{d}", .{item.meta.bullet.damage});
                                };
                                // Killing the bullet if we hit something
                                _ = self.items.orderedRemove(i);
                                len -= 1;
                            }
                        }
                    }
                }
            },
            else => continue,
        }
    }
}
