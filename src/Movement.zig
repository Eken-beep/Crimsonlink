const std = @import("std");
const rl = @import("raylib");
const Textures = @import("Textures.zig");
const Movement = @import("Movement.zig");
const Self = @This();

pub const CollisionType = enum { Player, Bullet, Enemy, Wall };

pub const Hitbox = union(enum) { radius: u16, rectangle: @Vector(2, f32) };

pub const CollisionItem = struct { type: CollisionType, pos: @Vector(2, f32), hitbox: Hitbox, image: ?*rl.Texture2D };

allocator: std.mem.Allocator,
items: std.ArrayList(CollisionItem),
textures: []rl.Texture2D,
width: u16,
height: u16,

pub fn init(alloc: std.mem.Allocator, width: u16, height: u16, images: []rl.Image) !Self {
    var t = try alloc.alloc(rl.Texture2D, 1);
    for (0..Textures.images.len) |i| {
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
    for (0..Textures.images.len) |i| {
        rl.unloadTexture(self.textures[i]);
    }
    self.allocator.free(self.textures);
}

pub fn addItem(self: *Self, ctype: CollisionType, x: f32, y: f32, hitbox: Hitbox, image: *rl.Texture2D) !*CollisionItem {
    const p: *CollisionItem = try self.items.addOne();
    p.* = CollisionItem{ .type = ctype, .pos = @Vector(2, f32){ x, y }, .hitbox = hitbox, .image = image };
    return p;
}

pub fn moveItem(self: *Self, i: *Movement.CollisionItem, to: @Vector(2, f32)) void {
    var goal = i.pos + to;
    const fw: f32 = @floatFromInt(self.width);
    const fh: f32 = @floatFromInt(self.height);
    if (goal[0] > fw) goal[0] = fw else if (goal[0] < 0) goal[0] = 0;
    if (goal[1] > fh) goal[1] = fh else if (goal[1] < 0) goal[1] = 0;
    i.pos = goal;
}
