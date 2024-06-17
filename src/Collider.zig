const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Items = @import("Items.zig");

pub const Collider = struct {
    pos: @Vector(2, f32),
    vel: @Vector(2, f32),
    hitbox: @Vector(2, f16),
    centerpoint: @Vector(2, f16),
    collision: ColliderType,
    effect: @Vector(2, f32) = @splat(0),
    // These two are only here because many different world objects can have weapons
    // Should be null on everything that can't wield a weapon
    // If this is null then the guy is permanently barehanded
    weapon_mount: ?@Vector(2, f16) = null,
    // However only this being null means he is temporarily barehanded
    weapon: ?Items.Weapon = null,
};

const ColliderType = enum {
    kinetic,
    transparent, // for the likes of items
    static,
};

// The usizes here reference the object to be affected by it
const Resolution = union(enum) {
    none,
    kill,
    spread,
    pickup: usize,
    stop: Direction,
    damage: usize,
};

const Direction = enum {
    up,
    down,
    left,
    right,
    invalid,
};

pub fn applyVelocity(
    collider: *Collider,
    object_type: World.WorldItemMetadata,
    world_size: @Vector(2, u16),
    world_items: []World.WorldItem,
) Resolution {
    var resolution_result: Resolution = .none;
    var velocity: @Vector(2, f32) = collider.vel;
    // The fact that whether or not the enemies are pushed aside are checked for collision will surely lead to some intreseting bugs I can't be bothered to fix now
    const goal = collider.pos + collider.vel * @as(@Vector(2, f32), @splat(rl.getFrameTime()));
    const world_w: f32 = @floatFromInt(world_size[0]);
    const world_h: f32 = @floatFromInt(world_size[1]);
    velocity[0] *= rl.getFrameTime();
    velocity[1] *= rl.getFrameTime();

    for (world_items, 0..) |item, i| {
        // So that we don't compare with the same item
        if (!(@reduce(.And, item.c.pos == collider.*.pos) and @reduce(.And, item.c.vel == collider.*.vel))) {
            if (doOverlap(
                collider.pos[0] + velocity[0],
                collider.pos[1] + velocity[1],
                collider.hitbox[0],
                collider.hitbox[1],
                item.c.pos[0],
                item.c.pos[1],
                item.c.hitbox[0],
                item.c.hitbox[1],
            )) {
                resolution_result = resolve(collider.*, object_type, item.c, i, item.meta);
                if (resolution_result == .spread) {
                    velocity += makeOppositeVelocities(collider.*, item.c);
                }
            }
        }
    }

    if (resolution_result != .stop) {
        if (object_type == .player or object_type == .enemy) {
            if (goal[0] < 0 or goal[0] + collider.hitbox[0] > world_w) velocity[0] = 0;
            if (goal[1] < 0 or goal[1] + collider.hitbox[1] > world_h) velocity[1] = 0;
        } else if (object_type == .bullet) {
            if (collider.pos[0] < 0 or
                collider.pos[1] < 0 or
                collider.pos[0] > world_w or
                collider.pos[1] > world_h) resolution_result = Resolution.kill;
        }
    } else {
        std.debug.print("{any}\n", .{resolution_result.stop});
        velocity = getClearedVectorComponent(velocity, resolution_result.stop);
    }
    collider.pos += velocity;

    // Will just be none if nothing happened
    return resolution_result;
}

// This produces the spread between objects who collide but don't affect eachother
fn makeOppositeVelocities(a: Collider, b: Collider) @Vector(2, f32) {
    const angle = std.math.atan2(a.pos[1] - b.pos[1], a.pos[0] - b.pos[0]);
    return @Vector(2, f32){
        @cos(angle) * 0.3,
        @sin(angle) * 0.3,
    };
}

fn getCollisionDirection(c1: Collider, c2: Collider) Direction {
    const c1c = getColliderCorners(c1);
    const c2c = getColliderCorners(c2);

    if (c1c[1][1] > c2c[2][1]) return .up;
    if (c1c[2][1] < c2c[1][1]) return .down;

    if (c1c[1][0] > c2c[0][0]) return .left;
    if (c1c[0][0] < c2c[1][0]) return .right;
    return .invalid;
}

fn getColliderCorners(c: Collider) [4]@Vector(2, f32) {
    // The corners of each collider
    // laid out like the quadrants of a coordinate system
    return [4]@Vector(2, f32){
        c.pos + @Vector(2, f32){ c.hitbox[0], 0 },
        c.pos,
        c.pos + @Vector(2, f32){ 0, c.hitbox[1] },
        c.pos + c.hitbox,
    };
}

// Would be kinda fun to have non-rectangular colliders here
// but that would require proper trigonometry and more complex systems to describe objects
fn getClearedVectorComponent(v: @Vector(2, f32), direction: Direction) @Vector(2, f32) {
    return switch (direction) {
        .up, .down => @Vector(2, f32){ v[0], 0 },
        .left, .right => @Vector(2, f32){ 0, v[1] },
        else => v,
    };
}

// Given there is a collision, what should we do?
fn resolve(
    a: Collider,
    a_meta: World.WorldItemMetadata,
    b: Collider,
    b_index: usize,
    b_meta: World.WorldItemMetadata,
) Resolution {
    // This whole function is horrible but idrc
    if (a_meta == .player and b_meta == .item) return Resolution{ .pickup = b_index };
    // If this isn't a possible item pickup then just exit for all transparent items
    if (b.collision == .transparent) return .none;
    if (a_meta == .bullet and b.collision == .static) return .kill;
    if (a_meta == .bullet and b.collision == .kinetic) {
        if (a_meta.bullet.owner == .enemy and b_meta == .player) {
            return Resolution{ .damage = b_index };
        } else if (a_meta.bullet.owner == .player and b_meta == .enemy) {
            return Resolution{ .damage = b_index };
            // We do the following to break the function before checking if spread should happen, no spread with bullets
        } else if (a_meta.bullet.owner == .player and b_meta == .player) {
            return .none;
        } else if (a_meta.bullet.owner == .enemy and b_meta == .enemy) {
            return .none;
        }
    }
    // Just check one way between bullet and kinetic
    if (b_meta == .bullet and a.collision == .kinetic) return .none;
    if (a.collision == .kinetic and b.collision == .kinetic) {
        if (a_meta == .bullet and b_meta == .bullet) return .none;
        return .spread;
    }
    if (a.collision == .kinetic and b.collision == .static) return .{ .stop = getCollisionDirection(a, b) };
    // As long as it isn't an enemy and player colliding
    if (a.collision == b.collision) {
        if (a_meta == .enemy and b_meta == .player) return Resolution{ .damage = b_index } else return .none;
    }
    return .none;
}

fn doOverlap(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return ((x1 < x2 + w2) and (x2 < x1 + w1) and (y1 < y2 + h2) and (y2 < y1 + h1));
}
