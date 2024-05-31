const std = @import("std");
const rl = @import("raylib");
const World = @import("World.zig");
const Self = @This();

const BASEXP = 100;

hp: u16,
max_hp: u16,
damage: u8,
movementspeed: f32 = 300,

inventory: struct {
    const Inventory = @This();
    // a null slot is empty
    items: [10]?Item,
    dogecoins: u10,
    // I seriously don't know why the last one has to be a space for the formatting to work
    // Without it it just stops doing what it should and puts 50 in place of 5 and does not pad correctly
    dogecoin_str_rep: [4:0]u8 = [4:0]u8{ '0', '0', '0', ' ' },
    pub fn add(self: *Inventory, i: *Item) error{InventoryFull}!void {
        if (i.type == .money) {
            self.dogecoins += i.ammount;
            std.mem.copyForwards(u8, &self.dogecoin_str_rep, std.fmt.bufPrintZ(&self.dogecoin_str_rep, "{d:0>3}", .{self.dogecoins}) catch blk: {
                break :blk &[4:0]u8{ '9', '9', '9', ' ' };
            });
            return;
        }
        for (self.items, 0..) |item, index| {
            if (item) |used_slot| {
                if (used_slot.type == i.type) {
                    // Check how much overflow we get and carry that over to the next slot if it happens
                    const overflow: u8 = used_slot.ammount +% i.ammount;
                    if (overflow < used_slot.ammount) {
                        self.items[index].?.ammount = overflow;
                        return;
                    } else {
                        self.items[index].?.ammount = 255;
                        i.ammount -= overflow;
                        continue;
                    }
                }
            }
            // If no previous stack is found just continue searching for an empty slot to put it in
        } else for (self.items, 0..) |item, index| {
            if (item == null) {
                self.items[index] = i.*;
                return;
            }
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
        slime,
        slug_eye,

        ammo,
        money,
    },
};

pub fn mainAttack(self: *Self, world: *World) !void {
    const player_pos = world.items.items[0].c.pos + world.items.items[0].c.centerpoint;
    const mx: f32 = @floatFromInt(rl.getMouseX());
    const my: f32 = @floatFromInt(rl.getMouseY());
    const angle = std.math.atan2(player_pos[1] - my, player_pos[0] - mx);
    try world.addItem(.{
        .type = World.WorldPacket.bullet,
        .x = player_pos[0],
        .y = player_pos[1],
        .vx = -1000 * @cos(angle),
        .vy = -1000 * @sin(angle),
        .damage = self.damage,
        .owner = .player,
    });
}
