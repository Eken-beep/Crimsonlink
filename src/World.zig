const std = @import("std");
const SDL = @import("sdl2");

const Window = @import("Window.zig");
const Input = @import("Input.zig");
const Textures = @import("Textures.zig");
const Player = @import("Player.zig");
const Collider = @import("Collider.zig");
const Level = @import("Level.zig");

const Self = @This();

const PLAYERSPRITEWIDTH = 32;
const DRAW_HITBOXES = true;

pub const WorldPacket = enum {
    player,
    enemy,
    bullet,
    item,
    static,
    door,
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
    //    door: struct {
    //        direction: Level.Direction !.None
    //        texture
    //    }
};

pub const WorldItem = struct {
    c: Collider.Collider,
    meta: WorldItemMetadata,
    hp: u16,
};

pub const WorldItemMetadata = union(enum) {
    player: struct {
        state: State = .idle,
        animation: Textures.Animation,
    },
    bullet: struct {
        damage: u16,
        owner: enum {
            player,
            enemy,
        },
    },
    enemy: struct {
        animation: Textures.Animation,
        score_bonus: u32,
        self_timer: f32 = 0,
        melee_timeout: f32 = 0,
        attack_time: f32 = 1,
        type: EnemyType,
        damage: u16,
        state: State = .idle,
        attack_type: enum(u8) {
            range = 1,
            melee = 2,
        },
    },
    item: struct {
        dt: f32,
        payload: Player.Item,
    },
    static,
    door: struct {
        direction: Level.Direction,
    },
};

pub const EnemyType = enum {
    blooby,
    slug,

    pub fn drop(self: *@This(), c: Collider.Collider, textures: Textures.TextureMap, world: *Self) !void {
        switch (self.*) {
            .slug => try world.addItem(.{
                .type = WorldPacket.item,
                .x = c.pos[0],
                .y = c.pos[1],
                .itemtype = .slime,
                .ammount = 1,
                .sprite = (textures.get("slime") orelse textures.get("fallback_single").?).single,
            }),
            else => {},
        }
    }
};

pub const State = enum {
    idle,
    jumping,
    shooting,
    walking,
};

// Here the player is expected to be items[0] in all cases
items: std.ArrayList(WorldItem),
allocator: std.mem.Allocator,
dim: @Vector(2, u16),
map: SDL.Texture,
completed: bool = false,
paused: bool = false,
time: f32 = 0,

pub fn init(dim: @Vector(2, u16), map: SDL.Texture, allocator: std.mem.Allocator) !Self {
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
            const img_info = try switch (item.animation.frames[0].idle) {
                .slice => |a| a[0],
                .single => |a| a,
            }.query();
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @Vector(2, f16){ 18 * 4, 52 * 4 },
                    .centerpoint = @Vector(2, f16){ 9 * 4, 26 * 4 },
                    .flags = .{
                        .kinetic = true,
                        .transparent = false,
                    },
                    .render_width = img_info.width * 4,
                    .render_height = img_info.height * 4,
                    .texture_offset = @Vector(2, f16){ -PLAYERSPRITEWIDTH, 0 },
                    .weapon_mount = @Vector(2, f16){ 36, 104 },
                },
                .hp = 1,
                .meta = WorldItemMetadata{ .player = .{
                    .animation = item.animation,
                } },
            });
        },
        .enemy => {
            const img_info = try switch (item.animation.frames[0].idle) {
                .slice => |a| a[0],
                .single => |a| a,
            }.query();
            try self.items.append(WorldItem{
                .c = .{
                    .pos = @Vector(2, f32){ item.x, item.y },
                    .vel = @splat(0),
                    .hitbox = @splat(50),
                    .centerpoint = @splat(25),
                    .render_width = img_info.width * 4,
                    .render_height = img_info.height * 4,
                    .flags = .{
                        .kinetic = true,
                        .transparent = false,
                    },
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
                    .render_width = 10,
                    .render_height = 10,
                    .flags = .{
                        .kinetic = true,
                        .transparent = true,
                    },
                    .texture_offset = @Vector(2, f16){ -2.5, -2.5 },
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
                    .hitbox = @splat(80),
                    .centerpoint = @splat(5),
                    .render_width = 80,
                    .render_height = 80,
                    .sprite = item.sprite,
                    .flags = .{
                        .kinetic = false,
                        .transparent = true,
                    },
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
                        @as(f16, @floatFromInt(if (item.w != null) item.w.? else (try item.sprite.query()).width)),
                        @as(f16, @floatFromInt(if (item.h != null) item.h.? else (try item.sprite.query()).height)),
                    },
                    .centerpoint = @splat(0),
                    .render_width = (try item.sprite.query()).width,
                    .render_height = (try item.sprite.query()).height,
                    .sprite = item.sprite,
                    .flags = .{
                        .kinetic = false,
                        .transparent = false,
                    },
                    .texture_offset = @splat(0),
                },
                .hp = 1,
                .meta = WorldItemMetadata.static,
            });
        },
        .door => {
            const ww: f32 = @floatFromInt(self.dim[0]);
            const wh: f32 = @floatFromInt(self.dim[1]);
            try self.items.append(WorldItem{
                .c = .{
                    .pos = switch (item.side) {
                        .North => @Vector(2, f32){ ww / 2 - 50, 0 },
                        .South => @Vector(2, f32){ ww / 2 - 50, wh - 5 - Window.WALLSIZE },
                        .East => @Vector(2, f32){ ww - 5 - Window.WALLSIZE, wh / 2 - 50 },
                        .West => @Vector(2, f32){ Window.WALLSIZE, wh / 2 - 50 },
                        else => unreachable,
                    },
                    .vel = @splat(0),
                    .hitbox = switch (item.side) {
                        .North, .South => @Vector(2, f16){ 100, 5 },
                        else => @Vector(2, f16){ 5, 100 },
                    },
                    .render_width = switch (item.side) {
                        .North, .South => 100,
                        else => 100,
                    },
                    .render_height = switch (item.side) {
                        .North, .South => 5,
                        else => 100,
                    },
                    .sprite = item.sprite,
                    .centerpoint = @splat(0),
                    .flags = .{
                        .kinetic = false,
                        .transparent = false,
                    },
                    .texture_offset = @splat(0),
                },
                .hp = 1,
                .meta = WorldItemMetadata{ .door = .{
                    .direction = item.side,
                } },
            });
        },
        //else => {},
    }
}

pub fn iterate(
    self: *Self,
    r: *SDL.Renderer,
    window: *Window,
    player: *Player,
    world_should_switch: *Level.Direction,
    textures: Textures.TextureMap,
    dt: f32,
    keybinds: std.AutoHashMap(i10, Input.InputAction),
    paused: bool,
) !bool {
    self.time += dt;

    var len = self.items.items.len;
    var i: u16 = 0;

    // local copy to keep track of if we've won
    var found_enemy: bool = false;
    var found_player: bool = false;
    defer self.completed = !found_enemy and !paused;

    loop: while (len > i) : (i += 1) {
        const item = self.items.items[i];
        if (item.meta == .enemy) {
            found_enemy = true;
        }

        if (self.items.items[i].c.sprite) |*sprite| {
            // This draws the shadow/speedy things behind the sprite if it's jumping
            blk: {
                switch (item.meta) {
                    .enemy, .player => {
                        if (item.meta == .enemy) {
                            if (item.meta.enemy.state != .jumping) break :blk;
                        } else if (item.meta == .player) {
                            if (item.meta.player.state != .jumping) break :blk;
                        }

                        var j: f32 = 1;
                        while (j < 4) : ({
                            j += 1;
                            try sprite.*.setAlphaMod(@as(u8, @intFromFloat(255 / (5 - j))));
                        }) {
                            const shadow_pos: @Vector(2, c_int) = bll: {
                                const scaled_v = item.c.vel * @Vector(2, f32){ 0.07, 0.07 };
                                const moved_v = item.c.texture_offset + scaled_v * @Vector(2, f32){ -j, -j };
                                break :bll @intFromFloat(@as(@Vector(2, f32), @splat(window.scale)) * (moved_v + item.c.pos) + window.origin);
                            };
                            try r.copy(sprite.*, .{
                                .x = shadow_pos[0],
                                .y = shadow_pos[1],
                                .width = item.c.render_width,
                                .height = item.c.render_height,
                            }, null);
                        }
                    },
                    else => {},
                }
            }
            try sprite.*.setAlphaMod(255);

            try r.copy(
                sprite.*,
                .{
                    .x = @as(i32, @intFromFloat(window.scale * (item.c.pos[0] + item.c.texture_offset[0]) + window.origin[0])),
                    .y = @as(i32, @intFromFloat(window.scale * (item.c.pos[1] + item.c.texture_offset[1]) + window.origin[1])),
                    .width = item.c.render_width,
                    .height = item.c.render_height,
                },
                null,
            );
        } else {
            //std.log.warn("Collider {d} of type {any} has no set sprite\n", .{ i, item.meta });
            try r.setColor(SDL.Color.magenta);
            try r.fillRect(.{
                .x = @as(i32, @intFromFloat(window.scale * (item.c.pos[0] + item.c.texture_offset[0]) + window.origin[0])),
                .y = @as(i32, @intFromFloat(window.scale * (item.c.pos[1] + item.c.texture_offset[1]) + window.origin[1])),
                .width = item.c.render_width,
                .height = item.c.render_height,
            });
        }

        if (item.hp < 1 and !paused) {
            if (item.meta == .enemy) {
                player.addScore(item.meta.enemy.score_bonus, self.time);
                try self.items.items[i].meta.enemy.type.drop(item.c, textures, self);
            }
            _ = self.items.orderedRemove(i);
            len -= 1;
            continue :loop;
        }

        if (!paused) switch (item.meta) {
            .player => |p| {
                found_player = true;
                self.items.items[i].meta.player.state = if (item.c.vel[0] != 0 or item.c.vel[1] != 0) .walking else .idle;
                // check if velocity isn't 0 to check for movement
                self.items.items[i].meta.player.animation.step(dt, item.meta.player.state);

                // I give up just find the wierd movement and kill it
                const ks = SDL.getKeyboardState();

                if (item.c.vel[0] > 0 and !ks.isPressedInt(getKeyOfAction(.moveright, keybinds))) self.items.items[i].c.vel[0] = 0;
                if (item.c.vel[1] > 0 and !ks.isPressedInt(getKeyOfAction(.movedown, keybinds))) self.items.items[i].c.vel[1] = 0;
                if (item.c.vel[0] < 0 and !ks.isPressedInt(getKeyOfAction(.moveleft, keybinds))) self.items.items[i].c.vel[0] = 0;
                if (item.c.vel[1] < 0 and !ks.isPressedInt(getKeyOfAction(.moveup, keybinds))) self.items.items[i].c.vel[1] = 0;

                self.items.items[i].c.sprite = self.items.items[i].meta.player.animation.getFrame(item.c.vel, p.state);
            },
            .enemy => |e| {
                self.items.items[i].c.vel = try stepAi(self, &self.items.items[i].meta, item.c, self.items.items[0].c, dt);
                self.items.items[i].c.sprite = self.items.items[i].meta.enemy.animation.getFrame(item.c.vel, e.state);
            },
            .item => |x| {
                self.items.items[i].meta.item.dt += dt;
                // Bouncy item
                self.items.items[i].c.pos += @Vector(2, f32){ 0, 10 * @cos(x.dt) };
            },
            else => {},
        };

        if (item.c.weapon_mount) |weapon_mountpoint| {
            if (item.meta == .player) {
                try r.copy(
                    player.forehand.texture,
                    .{
                        .x = @as(i32, @intFromFloat(window.scale * (item.c.pos[0] + weapon_mountpoint[0]) + window.origin[0])),
                        .y = @as(i32, @intFromFloat(window.scale * (item.c.pos[1] + weapon_mountpoint[1]) + window.origin[1])),
                        .width = item.c.render_width,
                        .height = item.c.render_height,
                    },
                    null,
                );
            }
        }

        // Then lastly we apply the velocity of the item
        if (item.c.flags.kinetic and !paused) {
            const result = Collider.applyVelocity(
                &self.items.items[i].c,
                dt,
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
                        // The players HP is not stored in the world
                        if (self.items.items[to].meta == .player) {
                            player.hp -|= item.meta.bullet.damage;
                        } else if (self.items.items[to].meta == .enemy) {
                            self.items.items[to].hp -|= item.meta.bullet.damage;
                        }
                        _ = self.items.orderedRemove(i);
                        len -= 1;
                    } else if (item.meta == .enemy) {
                        if (self.items.items[to].meta == .player and item.meta.enemy.melee_timeout > item.meta.enemy.attack_time) {
                            player.hp -|= item.meta.enemy.damage;
                            self.items.items[i].meta.enemy.melee_timeout = 0;
                        }
                    }
                },
                .pickup => |dropped_item| {
                    player.inventory.add(&self.items.items[dropped_item].meta.item.payload) catch continue :loop;
                    _ = self.items.orderedRemove(dropped_item);
                    len -= 1;
                },
                .goto => |to| {
                    switch (to) {
                        .up => world_should_switch.* = .North,
                        .down => world_should_switch.* = .South,
                        .right => world_should_switch.* = .East,
                        .left => world_should_switch.* = .West,
                        .invalid => world_should_switch.* = .None,
                    }
                },
                else => {},
            }
        }
    }
    // This is how we die for now
    if (!paused) std.debug.assert(found_player);
    // For setting the room data for later
    return self.completed;
}

fn getKeyOfAction(a: Input.InputAction, hm: std.AutoHashMap(i10, Input.InputAction)) i10 {
    var iter = hm.iterator();
    while (iter.next()) |e| {
        if (e.value_ptr.* == a) return e.key_ptr.*;
    }
    return 0;
}

fn stepAi(
    world: *Self,
    meta: *WorldItemMetadata,
    collider: Collider.Collider,
    player: Collider.Collider,
    dt: f32,
) !@Vector(2, f32) {
    const enemy = &meta.*.enemy;
    enemy.*.animation.step(dt, enemy.*.state);
    enemy.*.self_timer += dt;
    enemy.*.melee_timeout += dt;

    const angle = std.math.atan2(collider.pos[1] - player.pos[1], collider.pos[0] - player.pos[0]);
    var vel: @Vector(2, f32) = @splat(0);
    switch (enemy.type) {
        .slug => {
            enemy.*.state = if (collider.vel[0] != 0 or collider.vel[1] != 0) .walking else .idle;
            return @Vector(2, f32){ -100 * @cos(angle), -100 * @sin(angle) };
        },
        .blooby => {
            switch (enemy.state) {
                .idle => {
                    if (enemy.*.self_timer > 3) {
                        enemy.*.state = .jumping;
                        enemy.*.self_timer = 0;
                    }
                },
                .jumping => {
                    const t = meta.enemy.self_timer;
                    vel = .{
                        @cos(angle) * -100 * @exp(t + 1),
                        @sin(angle) * -100 * @exp(t + 1),
                    };

                    if (enemy.*.self_timer > 1) {
                        enemy.state = .shooting;
                        enemy.*.self_timer = 0;
                    }
                },
                .shooting => {
                    if (enemy.*.self_timer > 0.5) {
                        enemy.*.state = .idle;
                        enemy.*.self_timer = 0;
                        try world.addItem(.{
                            .type = WorldPacket.bullet,
                            .x = collider.pos[0] + collider.centerpoint[0],
                            .y = collider.pos[1] + collider.centerpoint[1],
                            .vx = 200,
                            .vy = 0,
                            .owner = .enemy,
                            .damage = enemy.damage,
                        });
                        try world.addItem(.{
                            .type = WorldPacket.bullet,
                            .x = collider.pos[0] + collider.centerpoint[0],
                            .y = collider.pos[1] + collider.centerpoint[1],
                            .vx = 0,
                            .vy = 200,
                            .owner = .enemy,
                            .damage = enemy.damage,
                        });
                        try world.addItem(.{
                            .type = WorldPacket.bullet,
                            .x = collider.pos[0] + collider.centerpoint[0],
                            .y = collider.pos[1] + collider.centerpoint[1],
                            .vx = -200,
                            .vy = 0,
                            .owner = .enemy,
                            .damage = enemy.damage,
                        });
                        try world.addItem(.{
                            .type = WorldPacket.bullet,
                            .x = collider.pos[0] + collider.centerpoint[0],
                            .y = collider.pos[1] + collider.centerpoint[1],
                            .vx = 0,
                            .vy = -200,
                            .owner = .enemy,
                            .damage = enemy.damage,
                        });
                    }
                },
                else => {},
            }
            return vel;
        },
    }
}
