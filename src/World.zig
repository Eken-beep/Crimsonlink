const std = @import("std");
const rl = @import("raylib");
const Window = @import("Window.zig");
const Input = @import("Input.zig");
const Textures = @import("Textures.zig");
const Player = @import("Player.zig");
const Collider = @import("Collider.zig");

const key = rl.KeyboardKey;

const Self = @This();

const PLAYERSPRITEWIDTH = 32;
const DRAW_HITBOXES = true;

pub const WorldPacket = enum {
    player,
    enemy,
    bullet,
    item,
    static,
    // What is expected from the different anonymous structs
    //    player: struct {
    //        x: f32,
    //        y: f32,
    //        img: []rl.Texture2D,
    //        weapon: Item.Weapon,
    //        weapon_mount: @Vector(2, f16),
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
    //    static: struct {
    //        x
    //        y
    //        sprite
    //    }
};

pub const WorldItem = struct {
    c: Collider.Collider,
    meta: WorldItemMetadata,
    hp: u16,
};

pub const WorldItemMetadata = union(enum) {
    player: Textures.animation(u2),
    bullet: struct {
        damage: u16,
        owner: enum {
            player,
            enemy,
        },
    },
    enemy: struct {
        animation: Textures.animation(u3),
        attack_type: enum(u8) {
            range = 1,
            melee = 2,
        },
    },
    item: struct {
        dt: f32,
        payload: Player.Item,
    },
    static: *rl.Texture2D,
};

// Everything dies if there are no items in the world, fix, needs a menu to return to or something
// The ai is retarded, fix

// Here the player is expected to be items[0] in all cases
items: std.ArrayList(WorldItem),
allocator: std.mem.Allocator,
dim: @Vector(2, u16),
map: *rl.Texture2D,
completed: bool = false,
paused: bool = false,

pub fn init(dim: @Vector(2, u16), map: *rl.Texture2D, allocator: std.mem.Allocator) !Self {
    return Self{
        .items = std.ArrayList(WorldItem).init(allocator),
        .allocator = allocator,
        .dim = dim,
        .map = map,
    };
}

// For adding items manually
pub fn addItem(self: *Self, item: anytype) !void {
    switch (item.type) {
        .player => {
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @Vector(2, f16){ 18 * 4, 52 * 4 },
                    .centerpoint = @Vector(2, f16){ 9 * 4, 26 * 4 },
                    .collision = .kinetic,
                    .texture_offset = @Vector(2, f16){ -PLAYERSPRITEWIDTH, 0 },
                    .weapon = item.weapon,
                    .weapon_mount = @Vector(2, f16){ 36, 104 },
                },
                .hp = 1,
                .meta = WorldItemMetadata{ .player = item.animation },
            });
        },
        .enemy => {
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @splat(50),
                    .centerpoint = @splat(25),
                    .collision = .kinetic,
                    .texture_offset = @splat(0),
                },
                .hp = item.hp,
                .meta = WorldItemMetadata{ .enemy = .{
                    .animation = item.animation,
                    .attack_type = item.attack_type,
                } },
            });
        },
        .bullet => {
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @Vector(2, f32){ item.vx, item.vy },
                    .hitbox = @splat(5),
                    .centerpoint = @splat(25),
                    .collision = .kinetic,
                    .texture_offset = @Vector(2, f16){ 5, 5 },
                },
                .hp = item.damage,
                .meta = WorldItemMetadata{ .bullet = .{
                    .damage = item.damage,
                    .owner = item.owner,
                } },
            });
        },
        .item => {
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @splat(10),
                    .centerpoint = @splat(5),
                    .collision = .transparent,
                    .texture_offset = @splat(0),
                },
                .hp = 1,
                .meta = WorldItemMetadata{ .item = .{ .dt = 0, .payload = Player.Item{
                    .ammount = item.ammount,
                    .image = item.sprite,
                    .type = item.itemtype,
                } } },
            });
        },
        .static => {
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @Vector(2, f16){
                        @as(f16, @floatFromInt(item.sprite.*.width)),
                        @as(f16, @floatFromInt(item.sprite.*.height)),
                    },
                    .centerpoint = @splat(0),
                    .collision = .static,
                    .texture_offset = @splat(0),
                },
                .hp = 1,
                .meta = WorldItemMetadata{ .static = item.sprite },
            });
        },
        //else => {},
    }
}

pub fn iterate(self: *Self, window: *Window, player: *Player) void {
    var len = self.items.items.len;
    var i: u16 = 0;

    // local copy to keep track of if we've won
    var found_enemy: bool = false;
    defer self.completed = !found_enemy;

    loop: while (len > i) : (i += 1) {
        const item = self.items.items[i];
        if (item.meta == .enemy) found_enemy = true;

        if (item.hp < 1) {
            _ = self.items.orderedRemove(i);
            len -= 1;
            continue :loop;
        }

        switch (item.meta) {
            .player => |p| {
                // check if velocity isn't 0 to check for movement
                self.items.items[i].meta.player.step(rl.getFrameTime(), item.c.vel[0] != 0 or item.c.vel[1] != 0);

                // I give up just find the wierd movement and kill it
                if (item.c.vel[0] > 0 and rl.isKeyUp(key.key_d)) self.items.items[i].c.vel[0] = 0;
                if (item.c.vel[1] > 0 and rl.isKeyUp(key.key_s)) self.items.items[i].c.vel[1] = 0;
                if (item.c.vel[0] < 0 and rl.isKeyUp(key.key_a)) self.items.items[i].c.vel[0] = 0;
                if (item.c.vel[1] < 0 and rl.isKeyUp(key.key_w)) self.items.items[i].c.vel[1] = 0;

                rl.drawTextureEx(
                    p.frames[p.current_frame],
                    makeRlVec2(self.items.items[i].c.pos + item.c.texture_offset, window.origin, window.scale),
                    0,
                    window.scale * Window.PXSCALE,
                    rl.Color.white,
                );
            },
            .bullet => {
                rl.drawCircle(
                    @as(i32, @intFromFloat(window.scale * (item.c.pos[0] + item.c.texture_offset[0]) + window.origin[0])),
                    @as(i32, @intFromFloat(window.scale * (item.c.pos[1] + item.c.texture_offset[1]) + window.origin[1])),
                    5 * window.scale,
                    rl.Color.pink,
                );
            },
            .enemy => |e| {
                self.items.items[i].meta.enemy.animation.step(rl.getFrameTime(), true);
                // This is how we do pathfinding for now
                if (e.attack_type == .melee) {
                    const angle = std.math.atan2(item.c.pos[1] - self.items.items[0].c.pos[1], item.c.pos[0] - self.items.items[0].c.pos[0]);
                    self.items.items[i].c.vel = @Vector(2, f32){ -100 * @cos(angle), -100 * @sin(angle) };
                }

                rl.drawTextureEx(
                    e.animation.frames[e.animation.current_frame],
                    makeRlVec2(item.c.pos + item.c.texture_offset, window.origin, window.scale),
                    0,
                    window.scale * Window.PXSCALE,
                    rl.Color.white,
                );
            },
            .item => |x| {
                self.items.items[i].meta.item.dt += rl.getFrameTime();
                // Bouncy item
                const vpos = item.c.pos + @Vector(2, f32){ 0, 10 * @sin(x.dt) };
                rl.drawTextureEx(
                    x.payload.image.*,
                    makeRlVec2(vpos + item.c.texture_offset, window.origin, window.scale),
                    0,
                    window.scale * Window.PXSCALE,
                    rl.Color.white,
                );
            },
            .static => |sprite| {
                if (DRAW_HITBOXES) drawHitbox(
                    item.c.hitbox * @as(@Vector(2, f32), @splat(window.scale)),
                    (item.c.pos * @as(@Vector(2, f32), @splat(window.scale))) + window.origin,
                );
                rl.drawTextureEx(
                    sprite.*,
                    makeRlVec2(item.c.pos + item.c.texture_offset, window.origin, window.scale),
                    0,
                    window.scale * Window.PXSCALE,
                    rl.Color.white,
                );
            },
        }

        if (item.c.weapon_mount) |weapon_mountpoint| {
            if (item.c.weapon) |weapon| {
                rl.drawTextureEx(
                    weapon.texture.*,
                    makeRlVec2(item.c.pos + weapon_mountpoint - item.c.weapon.?.handle, window.origin, window.scale),
                    0,
                    window.scale * Window.PXSCALE,
                    rl.Color.white,
                );
            }
        }

        // Then lastly we apply the velocity of the item
        if (item.c.collision == .kinetic) {
            if (DRAW_HITBOXES) drawHitbox(
                item.c.hitbox * @as(@Vector(2, f32), @splat(window.scale)),
                (item.c.pos * @as(@Vector(2, f32), @splat(window.scale))) + window.origin,
            );
            const result = Collider.applyVelocity(
                &self.items.items[i].c,
                item.meta,
                self.dim,
                self.items.items,
            );
            switch (result) {
                .kill => {
                    _ = self.items.orderedRemove(i);
                    len -= 1;
                },
                .damage => |to| {
                    if (item.meta == .bullet) {
                        self.items.items[to].hp -|= item.meta.bullet.damage;
                        _ = self.items.orderedRemove(i);
                        len -= 1;
                    } else if (item.meta == .enemy) {
                        // enemy stuff
                    }
                },
                .pickup => |dropped_item| {
                    player.inventory.add(&self.items.items[dropped_item].meta.item.payload) catch continue :loop;
                    _ = self.items.orderedRemove(dropped_item);
                    len -= 1;
                },
                else => {},
            }
        }
    }
}

fn drawHitbox(hb: @Vector(2, f32), pos: @Vector(2, f32)) void {
    const x: i32 = @intFromFloat(pos[0]);
    const y: i32 = @intFromFloat(pos[1]);
    const w: i32 = @intFromFloat(hb[0]);
    const h: i32 = @intFromFloat(hb[1]);
    rl.drawRectangleLines(x, y, w, h, rl.Color.pink);
}

fn makeRlVec2(v: @Vector(2, f32), offset: @Vector(2, f32), scale: f32) rl.Vector2 {
    return rl.Vector2.init(v[0] * scale + offset[0], v[1] * scale + offset[1]);
}
