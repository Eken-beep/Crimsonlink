const std = @import("std");
const rl = @import("raylib");
const Textures = @import("Textures.zig");
const Self = @This();

pub const CollisionType = enum { Player, Bullet, Enemy, Wall };

pub const Hitbox = union(enum) { radius: f32, rectangle: @Vector(2, f32) };

pub const CollisionItem = struct { type: CollisionType, pos: @Vector(2, f32), hitbox: Hitbox, image: ?*rl.Texture2D, velocity: @Vector(2, f32) };

allocator: std.mem.Allocator,
items: std.ArrayList(CollisionItem),
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
        .items = std.ArrayList(CollisionItem).init(alloc),
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
    try self.items.append(CollisionItem{ .type = ctype, .pos = @Vector(2, f32){ x, y }, .hitbox = hitbox, .image = image, .velocity = velocity });
}

pub fn moveItem(self: *Self, i: *Self.CollisionItem, to: @Vector(2, f32)) void {
    var goal = i.pos + to;
    const fw: f32 = @floatFromInt(self.width);
    const fh: f32 = @floatFromInt(self.height);
    const hitbox: @Vector(2, f32) = blk: {
        const hb = i.hitbox;
        switch (hb) {
            .radius => |r| break :blk @Vector(2, f32){ r, r },
            .rectangle => |r| break :blk r,
        }
    };
    // we just make sure that the moved item doesn't go out of bounds, other collision handled elsewhere
    if (goal[0] + hitbox[0] > fw) goal[0] = fw - hitbox[0] else if (goal[0] - hitbox[0] < 0) goal[0] = hitbox[0];
    if (goal[1] + hitbox[1] > fh) goal[1] = fh - hitbox[0] else if (goal[1] - hitbox[0] < 0) goal[1] = hitbox[0];
    i.pos = goal;
}

pub fn stepVelocities(self: *Self) void {
    const world_width: f32 = @floatFromInt(self.width);
    const world_height: f32 = @floatFromInt(self.height);
    var len: usize = self.items.items.len;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const item = self.items.items[i];
        if (item.pos[0] > world_width or item.pos[0] < 0 or item.pos[1] > world_height or item.pos[1] < 0) {
            _ = self.items.orderedRemove(i);
            len -= 1;
        } else {
            const dt: f32 = rl.getFrameTime();
            const v = @Vector(2, f32){ item.velocity[0] * dt, item.velocity[1] * dt };
            self.items.items[i].pos += v;
        }
    }
}

// Private definitions
fn getPlayer(self: *Self) ?*Self.CollisionItem {
    return for (self.items.items, 0..) |item, i| {
        if (item.type == CollisionType.Player) break &self.items.items[i];
    } else null;
}
