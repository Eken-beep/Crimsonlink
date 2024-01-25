const rl = @import("raylib");
const std = @import("std");

const player_structure = @import("Player.zig");
const Input = @import("Input.zig");
const Movement = @import("Movement.zig");
const Textures = @import("Textures.zig");

const color = rl.Color;

const preferred_width = 1600;
const preferred_height = 900;

// TODO

const fullscreen = true;
pub fn main() anyerror!void {
    rl.setConfigFlags(rl.ConfigFlags.flag_window_resizable);
    rl.initWindow(preferred_width, preferred_height, "~Crimsonlink~");
    defer rl.closeWindow();

    var general_purpouse_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpouse_allocator.allocator();

    var images = [_]rl.Image{
        rl.loadImage("assets/Maincharacter1.png"),
    };
    var World: Movement = try Movement.init(gpa, 1600, 900, images[0..]);
    defer World.deinit();

    // our starting variables
    var current_width: i32 = preferred_width;
    var current_height: i32 = preferred_height;
    var scaling: f32 = 1;

    var player = player_structure{};
    _ = player;
    var world_player: *Movement.CollisionItem = try World.addItem(Movement.CollisionType.Player, 400, 225, Movement.Hitbox{ .radius = 50 }, &World.textures[0]);

    while (!rl.windowShouldClose()) {
        if (rl.isWindowResized()) {
            current_width = rl.getRenderWidth();
            current_height = rl.getRenderHeight();
            scaling = blk: {
                const sw: f32 = @floatFromInt(current_width);
                const sh: f32 = @floatFromInt(current_height);
                const xscale = sw / preferred_width;
                const yscale = sh / preferred_height;
                std.debug.print("Scaling factor of: x:{d}, y:{d}, using smallest\n", .{ xscale, yscale });
                if (xscale > yscale) break :blk yscale else break :blk xscale;
            };
        }

        World.moveItem(world_player, Input.updateMovements(300 * rl.getFrameTime()));

        // draw stuff woooo
        rl.beginDrawing();
        defer rl.endDrawing();

        const world_border = //if (World.active) |w|
            @Vector(2, i32){ scaler(scaling, World.width), scaler(scaling, World.height) };
        //else
        //    @Vector(2, i32){ scaler(scaling, preferred_width), scaler(scaling, preferred_height) };
        const origin = blk: {
            const rw = rl.getRenderWidth();
            const rh = rl.getRenderHeight();
            break :blk @Vector(2, i32){ @divTrunc(rw - world_border[0], 2), @divTrunc(rh - world_border[1], 2) };
        };

        rl.drawRectangle(origin[0], origin[1], world_border[0], world_border[1], color.white);
        const ox: f32 = @floatFromInt(origin[0]);
        const oy: f32 = @floatFromInt(origin[1]);
        for (World.items.items) |i| {
            if (i.image) |img| {
                const pos = rl.Vector2.init(scaling * i.pos[0] + ox, scaling * i.pos[1] + oy);
                rl.drawTextureEx(img.*, pos, 0, scaling, color.white);
            }
        }
        rl.clearBackground(color.black);
    }
}

fn scaler(scale: f32, x: i32) i32 {
    const fx: f32 = @floatFromInt(x);
    const r: i32 = @intFromFloat(scale * fx);
    return r;
}
