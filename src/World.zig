const std = @import("std");
const rl = @import("raylib");
const Window = @import("Window.zig");
const Input = @import("Input.zig");

const Self = @This();

pub const WorldPacket = union(enum) {
    player,
    enemy,
    bullet,
// What is expected from the different anonymous structs
//    player: struct {
//        x: f32,
//        y: f32,
//        img: *rl.Texture2D,
//    },
//    enemy: struct {
//        x: f32,
//        y: f32,
//        img: *rl.Texture2D,
//        hp: u8
//    },
//    bullet: struct {
//        x: f32,
//        y: f32,
//        vx: f32,
//        vy: f32,
//    },
};

pub const WorldItem = struct {
    c: Collider,
    meta: WorldItemMetadata,
    hp: u8,
};

pub const Collider = struct {
    pos: @Vector(2, f32),
    vel: @Vector(2, f32),
    hitbox: @Vector(2, f16),
};

pub const WorldItemMetadata = union(enum) {
    player: *rl.Texture2D,
    bullet,
    enemy: *rl.Texture2D,
};

// Here the player is expected to be items[0] in all cases
items: std.ArrayList(WorldItem),
allocator: std.mem.Allocator,
dim: @Vector(2, u16),
textures: []rl.Texture2D,

pub fn init(dim: @Vector(2, u16), allocator: std.mem.Allocator, images: []rl.Texture2D) !Self {
    return Self {
        .items = std.ArrayList(WorldItem).init(allocator),
        .allocator = allocator,
        .dim = dim,
        .textures = images,
    };
}

pub fn addItem(self: *Self, item: anytype) !void {
    switch(item.type) {
        .player => {
            try self.items.append(WorldItem{
                .c = Collider {
                    .pos = @Vector(2,f32) {item.x, item.y},
                    .vel = @splat(0),
                    .hitbox = @splat(50)
                },
                .hp = 1,
                .meta = WorldItemMetadata { .player = item.img },
            });
        },
        .enemy => {
            try self.items.append(WorldItem{
                .c = Collider {
                    .pos = @Vector(2,f32) {item.x, item.y},
                    .vel = @splat(0),
                    .hitbox = @splat(50)
                },
                .hp = item.hp,
                .meta = WorldItemMetadata { .enemy = item.img },
            });
        },
        .bullet => {
            try self.items.append(WorldItem{
                .c = Collider {
                    .pos = @Vector(2, f32) {item.x, item.y},
                    .vel = @Vector(2, f32) {item.vx, item.vy},
                    .hitbox = @splat(50)
                },
                .hp = 1,
                .meta = WorldItemMetadata { .player = item.img },
            });
        },
    }
}

pub fn iterate(self: *Self, window: *Window) void {
    var len = self.items.items.len;
    var i: u16 = 0;
    while(len > i) : (i += 1) {
        const item = self.items.items[i];
        self.items.items[i].c.pos += blk: {
            const goal = item.c.pos + item.c.vel;
            var velocity: @Vector(2, f32) = item.c.vel;
            const world_w: f32 = @floatFromInt(self.dim[0]);
            const world_h: f32 = @floatFromInt(self.dim[1]);

            if (item.meta == .player) {
                if (goal[0] < 0 or goal[0] + item.c.hitbox[0] > world_w) velocity[0] = 0;
                if (goal[1] < 0 or goal[1] + item.c.hitbox[1] > world_h) velocity[1] = 0;
            } 
            break :blk velocity;
        };
        switch (item.meta) {
            .player => |p| {
                self.items.items[i].c.vel = Input.playerMovement(500);
                rl.drawTextureEx(p.*, makeRlVec2(self.items.items[i].c.pos * @as(@Vector(2, f32), @splat(window.scale)), window.origin),
                0, window.scale, rl.Color.white);
            },
            else => {}
        }
    }
}

fn makeRlVec2(v: @Vector(2, f32), offset: @Vector(2, f32)) rl.Vector2 {
    return rl.Vector2.init(v[0] + offset[0], v[1] + offset[1]);
}

fn clamp(x: f32, y: f32, w: f16, h: f16, outer_w: f32, outer_h: f32) @Vector(2, f32) {
    var result: @Vector(2, f32) = @splat(0);
    if (x < 0) result[0] = 0
    else if (x + w > outer_w) result[0] = outer_w - w;
    if (y < 0) result[1] = 0
    else if (y + h > outer_h) result[1] = outer_h - h;
    return result;
}
