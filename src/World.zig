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
//        attack_type: .range | .melee
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
    enemy: struct {
        animation: Textures.animation(u3),
        attack_type: enum {
            range,
            melee,
        },
    },
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
                .meta = WorldItemMetadata { .enemy = .{
                    .animation = item.animation,
                    .attack_type = item.attack_type,
                }},
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
        self.items.items[i].c.pos += applyVelocity(self, item.c, item.meta);
        switch (item.meta) {
            .player => |p| {
                // check if velocity isn't 0 to check for movement
                self.items.items[i].meta.player.step(rl.getFrameTime(), item.c.vel[0] != 0 or item.c.vel[1] != 0);
                self.items.items[i].c.vel = Input.playerMovement(500);
                rl.drawTextureEx(p.frames[p.current_frame], makeRlVec2(self.items.items[i].c.pos, window.origin, window.scale),
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
                rl.drawCircle(@as(i32, @intFromFloat(window.scale*item.c.pos[0] + window.origin[0])), @as(i32, @intFromFloat(window.scale*item.c.pos[1] + window.origin[1])), 5*window.scale, rl.Color.pink);
            },
            .enemy => |e| {
                self.items.items[i].meta.enemy.animation.step(rl.getFrameTime(), true);
                rl.drawTextureEx(e.animation.frames[e.animation.current_frame], makeRlVec2(item.c.pos, window.origin, window.scale), 0, window.scale, rl.Color.white);
                if (e.attack_type == .melee) {
                    const angle = std.math.atan2(f32, item.c.pos[1]-self.items.items[0].c.pos[1], item.c.pos[0]-self.items.items[0].c.pos[0]);
                    self.items.items[i].c.vel = @Vector(2, f32) { -100*@cos(angle), -100*@sin(angle)};
                }
            },
        }
    }
}

fn applyVelocity(world: *Self, collider: Collider, object_type: WorldItemMetadata) @Vector(2, f32) {
    var velocity: @Vector(2, f32) = collider.vel;
    const goal = collider.pos + collider.vel * @as(@Vector(2, f32), @splat(rl.getFrameTime()));
    const world_w: f32 = @floatFromInt(world.dim[0]);
    const world_h: f32 = @floatFromInt(world.dim[1]);
    velocity[0] *= rl.getFrameTime();
    velocity[1] *= rl.getFrameTime();

    if (object_type == .player) {
        if (goal[0] < 0 or goal[0] + collider.hitbox[0] > world_w) velocity[0] = 0;
        if (goal[1] < 0 or goal[1] + collider.hitbox[1] > world_h) velocity[1] = 0;
    } 
    return velocity;

}

fn makeRlVec2(v: @Vector(2, f32), offset: @Vector(2, f32), scale: f32) rl.Vector2 {
    return rl.Vector2.init(v[0]*scale + offset[0], v[1]*scale + offset[1]);
}
