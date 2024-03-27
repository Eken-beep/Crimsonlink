const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Self = @This();

const BASEXP = 100;

hp: u8,
max_hp: u8,
damage: u8,
inventory: struct {
    const Inventory = @This();
    // a null slot is empty
    items: [10]?Item,
    dogecoins: u32,
    pub fn add(self: *Inventory, i: Item) error{InventoryFull}!void {
        for (self.items, 0..) |item, index| {
            if (item) |used_slot| {
                if (used_slot.type == i.type) {
                    self.items[index].?.ammount +|= i.ammount;
                    if (used_slot.ammount + i.ammount > 255) continue else break;
                }
            }
            // If no previous stack is found just continue searching for an empty slot to put it in
        } else for (self.items, 0..) |item, index| {
            if (item == null) self.items[index] = i;
            // If all else fails then don't pick up the item
        } else return error.InventoryFull;
    }
} = .{
    .dogecoins = 0,
    .items = [1]?Item{null} ** 10,
},

pub const Item = struct {
    image: *rl.Texture2D,
    // We use 255 stacks
    ammount: u8,
    type: enum {
        // Non consumables have no payload
        slime,
        slug_eye,

        ammo,
    },
};

pub fn mainAttack(self: *Self, world: *World) !void {
    const player_pos = world.items.items[0].c.pos + world.items.items[0].c.centerpoint;
    const mx: f32 = @floatFromInt(rl.getMouseX());
    const my: f32 = @floatFromInt(rl.getMouseY());
    const angle = std.math.atan2(f32, player_pos[1] - my, player_pos[0] - mx);
    try world.addItem(.{
        .type = World.WorldPacket.bullet,
        .x = player_pos[0],
        .y = player_pos[1],
        .vx = -1000 * @cos(angle),
        .vy = -1000 * @sin(angle),
        .damage = self.damage,
    });
}
