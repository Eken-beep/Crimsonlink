const std = @import("std");
const rl = @import("raylib");
const Window = @import("Window.zig");
const Input = @import("Input.zig");
const Textures = @import("Textures.zig");

const Self = @This();

pub const WorldPacket = union(enum) {
    player,
    enemy,
    bullet,
// What is expected from the different anonymous structs
//    player: struct {
//        x: f32,
//        y: f32,
//        img: []rl.Texture2D,
//    },
//    enemy: struct {
//        x: f32,
//        y: f32,
//        img: []rl.Texture2D,
//        hp: u8
//    },
//    bullet: struct {
//        x: f32,
//        y: f32,
//        vx: f32,
//        vy: f32,
//        damage: u8,
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
    player: Textures.animation(u2),
    bullet: u8,
    enemy: *rl.Texture2D,
};

// Here the player is expected to be items[0] in all cases
items: std.ArrayList(WorldItem),
allocator: std.mem.Allocator,
dim: @Vector(2, u16),
map: *rl.Texture2D,

pub fn init(dim: @Vector(2, u16), map: *rl.Texture2D, allocator: std.mem.Allocator) !Self {
    return Self {
        .items = std.ArrayList(WorldItem).init(allocator),
        .allocator = allocator,
        .dim = dim,
        .map = map,
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
                .meta = WorldItemMetadata { .player = item.animation },
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
                .hp = item.damage,
                .meta = WorldItemMetadata { .bullet = item.damage },
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
            velocity[0] *= rl.getFrameTime();
            velocity[1] *= rl.getFrameTime();
            break :blk velocity;
        };
        switch (item.meta) {
            .player => |p| {
                // check if velocity isn't 0 to check for movement
                self.items.items[i].meta.player.step(rl.getFrameTime(), item.c.vel[0] != 0 or item.c.vel[1] != 0);
                self.items.items[i].c.vel = Input.playerMovement(500);
                rl.drawTextureEx(p.frames[p.current_frame], makeRlVec2(self.items.items[i].c.pos * @as(@Vector(2, f32), @splat(window.scale)), window.origin),
                0, window.scale, rl.Color.white);
            },
            .bullet => {
                if (
                    item.c.pos[0] < 0 or
                    item.c.pos[1] < 0 or
                    item.c.pos[0] > @as(f32, @floatFromInt(self.dim[0])) or
                    item.c.pos[1] > @as(f32, @floatFromInt(self.dim[1]))
                ) {
                    _ = self.items.orderedRemove(i);
                    len -= 1;
                }
                rl.drawCircle(@as(i32, @intFromFloat(item.c.pos[0])), @as(i32, @intFromFloat(item.c.pos[1])), 5*window.scale, rl.Color.pink);
            },
            else => {}
        }
    }
}

fn makeRlVec2(v: @Vector(2, f32), offset: @Vector(2, f32)) rl.Vector2 {
    return rl.Vector2.init(v[0] + offset[0], v[1] + offset[1]);
}
