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
    centerpoint: @Vector(2, f16),
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

// Everything dies if there are no items in the world, fix, needs a menu to return to or something
// The ai is retarded, fix

// Here the player is expected to be items[0] in all cases
items: std.ArrayList(WorldItem),
allocator: std.mem.Allocator,
dim: @Vector(2, u16),
map: *rl.Texture2D,

pub fn init(dim: @Vector(2, u16), map: *rl.Texture2D, allocator: std.mem.Allocator) !Self {
    return Self{
        .items = std.ArrayList(WorldItem).init(allocator),
        .allocator = allocator,
        .dim = dim,
        .map = map,
    };
}

pub fn addItem(self: *Self, item: anytype) !void {
    switch (item.type) {
        .player => {
            try self.items.append(WorldItem{
                .c = Collider{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @splat(50),
                    .centerpoint = @splat(25),
                },
                .hp = 1,
                .meta = WorldItemMetadata{ .player = item.animation },
            });
        },
        .enemy => {
            try self.items.append(WorldItem{
                .c = Collider{ .pos = @Vector(2, f32){ item.x, item.y }, .vel = @splat(0), .hitbox = @splat(50), .centerpoint = @splat(25) },
                .hp = item.hp,
                .meta = WorldItemMetadata{ .enemy = .{
                    .animation = item.animation,
                    .attack_type = item.attack_type,
                } },
            });
        },
        .bullet => {
            try self.items.append(WorldItem{
                .c = Collider{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @Vector(2, f32){ item.vx, item.vy },
                    .hitbox = @splat(5),
                    .centerpoint = @splat(25),
                },
                .hp = item.damage,
                .meta = WorldItemMetadata{ .bullet = item.damage },
            });
        },
    }
}

pub fn iterate(self: *Self, window: *Window) void {
    var len = self.items.items.len;
    var i: u16 = 0;
    loop: while (len > i) : (i += 1) {
        const item = self.items.items[i];
        self.items.items[i].c.pos += applyVelocity(self, item.c, item.meta);

        if (item.hp < 1) {
            _ = self.items.orderedRemove(i);
            len -= 1;
            continue :loop;
        }

        switch (item.meta) {
            .player => |p| {
                // check if velocity isn't 0 to check for movement
                self.items.items[i].meta.player.step(rl.getFrameTime(), item.c.vel[0] != 0 or item.c.vel[1] != 0);
                self.items.items[i].c.vel = Input.playerMovement(500);

                rl.drawTextureEx(p.frames[p.current_frame], makeRlVec2(self.items.items[i].c.pos, window.origin, window.scale), 0, window.scale, rl.Color.white);
            },
            .bullet => {
                if (item.c.pos[0] < 0 or
                    item.c.pos[1] < 0 or
                    item.c.pos[0] > @as(f32, @floatFromInt(self.dim[0])) or
                    item.c.pos[1] > @as(f32, @floatFromInt(self.dim[1])))
                {
                    _ = self.items.orderedRemove(i);
                    len -= 1;
                    continue :loop;
                }

                rl.drawCircle(@as(i32, @intFromFloat(window.scale * item.c.pos[0] + window.origin[0])), @as(i32, @intFromFloat(window.scale * item.c.pos[1] + window.origin[1])), 5 * window.scale, rl.Color.pink);

                // The last thing to do with the bullet is checking if it hit something
                const index = getOverlappingItem(item.c.pos, item.c.hitbox, .enemy, self.items.items) catch {
                    continue :loop;
                };
                // for now bullets are op
                self.items.items[index].hp -= item.meta.bullet;
                _ = self.items.orderedRemove(i);
                len -= 1;
            },
            .enemy => |e| {
                self.items.items[i].meta.enemy.animation.step(rl.getFrameTime(), true);
                // This is how we do pathfinding for now
                if (e.attack_type == .melee) {
                    const angle = std.math.atan2(f32, item.c.pos[1] - self.items.items[0].c.pos[1], item.c.pos[0] - self.items.items[0].c.pos[0]);
                    self.items.items[i].c.vel = @Vector(2, f32){ -100 * @cos(angle), -100 * @sin(angle) };
                }

                rl.drawTextureEx(e.animation.frames[e.animation.current_frame], makeRlVec2(item.c.pos, window.origin, window.scale), 0, window.scale, rl.Color.white);
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

    if (object_type == .player or object_type == .enemy) {
        if (goal[0] < 0 or goal[0] + collider.hitbox[0] > world_w) velocity[0] = 0;
        if (goal[1] < 0 or goal[1] + collider.hitbox[1] > world_h) velocity[1] = 0;
    }
    return velocity;
}

const OverlapError = error{NoOverlap};

fn getOverlappingItem(item: @Vector(2, f32), item_size: @Vector(2, f32), goal_object: anytype, items: []WorldItem) OverlapError!usize {
    for (items, 0..) |other_item, i| {
        if (other_item.meta == goal_object) {
            if (doOverlap(item[0], item[1], item_size[0], item_size[1], other_item.c.pos[0], other_item.c.pos[1], other_item.c.hitbox[0], other_item.c.hitbox[1])) return i;
        }
    }
    return OverlapError.NoOverlap;
}

fn doOverlap(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return ((x1 < x2 + w2) and (x2 < x1 + w1) and (y1 < y2 + h2) and (y2 < y1 + h1));
}

fn makeRlVec2(v: @Vector(2, f32), offset: @Vector(2, f32), scale: f32) rl.Vector2 {
    return rl.Vector2.init(v[0] * scale + offset[0], v[1] * scale + offset[1]);
}
