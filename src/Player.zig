const std = @import("std");
const SDL = @import("sdl2");

const World = @import("World.zig");
const Window = @import("Window.zig");
const Items = @import("Items.zig");

const Self = @This();

const BASEXP = 100;

hp: u16,
max_hp: u16,
damage: u8,
movementspeed: f32 = 300,
score_multiplier: f32 = 1,
current_score: u32 = 0,
// Beautiful
current_score_str: [17:0]u8 = [17:0]u8{ ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },

forehand: Items.Weapon,
hand_placement: @Vector(2, f16),

inventory: struct {
    const Inventory = @This();
    // a null slot is empty
    items: [4]?Item,
    dogecoins: u10,
    dogecoin_str_rep: [3:0]u8 = [3:0]u8{ '0', '0', '0' },
    pub fn add(self: *Inventory, i: *Item) error{InventoryFull}!void {
        if (i.type == .money) {
            self.dogecoins += i.ammount;
            _ = std.fmt.bufPrint(&self.dogecoin_str_rep, "{d:0>3}", .{self.dogecoins}) catch {
                self.dogecoin_str_rep = [3:0]u8{ '9', '9', '9' };
            };
            return;
        }
        for (self.items, 0..) |item, index| {
            if (item) |used_slot| {
                if (used_slot.type == i.type) {
                    // Check how much overflow we get and carry that over to the next slot if it happens
                    const overflow: u8 = used_slot.ammount +% i.ammount;
                    if (overflow < 255 - used_slot.ammount) {
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
    .items = [1]?Item{null} ** 4,
},

pub const Item = struct {
    image: SDL.Texture,
    // We use 255 stacks
    ammount: u8,
    type: enum {
        slime,
        slug_eye,

        ammo,
        money,
    },
};

pub fn addScore(self: *Self, s: u32, time: f32) void {
    // fall off based on time in room by this function
    const score_falloff = 1 / @sqrt((time + 100) / 100);
    self.current_score += @as(u32, @intFromFloat(
        @as(f32, @floatFromInt(s)) * (self.score_multiplier * score_falloff),
    ));
    _ = std.fmt.bufPrint(&self.current_score_str, "Score: {d: <}", .{self.current_score}) catch {
        self.current_score_str = [17:0]u8{ '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_', '_' };
    };
}

pub fn mainAttack(self: *Self, mouse: @Vector(2, f32), world: *World, window: Window) !void {
    if (world.paused) return;
    try world.items.append(switch (self.forehand.range) {
        .melee => unreachable,
        .range => try Items.makeBullet(
            self.forehand,
            world.items.items[0],
            @Vector(2, f32){ mouse[0], mouse[1] },
            window.origin,
            window.scale,
        ),
    });
}
