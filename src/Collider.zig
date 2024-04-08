const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");

pub const Collider = struct {
    pos: @Vector(2, f32),
    vel: @Vector(2, f32),
    hitbox: @Vector(2, f16),
    centerpoint: @Vector(2, f16),
    collision: ColliderType,
};

const ColliderType = enum {
    kinetic,
    transparent, // for the likes of items
    static,
};

// The usizes here reference the object to be affected by it
const Resolution = union(enum) {
    none,
    stop,
    damage: usize,
    kill,
    pickup: usize,
};

// TODO
// apply a linear velocity to kinetic objects inside eachother to avoid deathstacks
pub fn applyVelocity(
    collider: *Collider,
    object_type: World.WorldItemMetadata,
    world_size: @Vector(2, u16),
    world_items: []World.WorldItem,
) Resolution {
    var resolution_result: Resolution = .none;
    var velocity: @Vector(2, f32) = collider.vel;
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
            )) resolution_result = resolve(collider.*, object_type, item.c, i, item.meta);
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
        // TODO
        // dont kill the entire velocity here but make the kinetic object slide instead
        velocity = @splat(0);
    }
    collider.pos += velocity;

    // Will just be none if nothing happened
    return resolution_result;
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
        }
    }
    if (a.collision == .kinetic and b.collision == .static) return .stop;
    // As long as it isn't an enemy and player colliding
    if (a.collision == b.collision) {
        if (a_meta == .enemy and b_meta == .player) return Resolution{ .damage = b_index } else return .none;
    }
    return .none;
}

fn doOverlap(x1: f32, y1: f32, w1: f32, h1: f32, x2: f32, y2: f32, w2: f32, h2: f32) bool {
    return ((x1 < x2 + w2) and (x2 < x1 + w1) and (y1 < y2 + h2) and (y2 < y1 + h1));
}
