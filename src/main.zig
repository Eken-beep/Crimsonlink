const rl = @import("raylib");
const std = @import("std");

const player_structure = @import("Player.zig");
const Input = @import("Input.zig");
const World = @import("World.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");

const color = rl.Color;

const preferred_width = 1600;
const preferred_height = 900;

// TODO
// Being able to shoot bullets
// Do something with the player data struct
// Spawn bullets that hurt the player
//

const fullscreen = true;
pub fn main() anyerror!void {
    rl.setConfigFlags(rl.ConfigFlags.flag_window_resizable);
    rl.initWindow(preferred_width, preferred_height, "~Crimsonlink~");
    defer rl.closeWindow();

    var general_purpouse_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpouse_allocator.allocator();

    var images: []rl.Image = try Textures.loadImages(gpa, Textures.all_images);
    defer gpa.free(images);

    var state: Statemanager.State = .Menu;

    var CurrentWorld: World = undefined;

    // our starting variables
    var current_width: i32 = preferred_width;
    var current_height: i32 = preferred_height;
    var scaling: f32 = 1;

    var player = player_structure{};

    while (!rl.windowShouldClose()) {
        player.attack_timeout += rl.getFrameTime();
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

        rl.beginDrawing();
        defer rl.endDrawing();

        // Only the drawing and variable updating part has to be different inbetween gamestates
        switch (state) {
            .Level => {
                const world_border = @Vector(2, i32){ scaler(scaling, CurrentWorld.width), scaler(scaling, CurrentWorld.height) };
                const origin = blk: {
                    const rw = rl.getRenderWidth();
                    const rh = rl.getRenderHeight();
                    break :blk @Vector(2, i32){ @divTrunc(rw - world_border[0], 2), @divTrunc(rh - world_border[1], 2) };
                };

                CurrentWorld.moveItem(&CurrentWorld.items.items[0], Input.updateMovements(300 * rl.getFrameTime()));
                CurrentWorld.stepVelocities();
                const mouse = scaleMouse(scaling, @Vector(2, i32){ rl.getMouseX(), rl.getMouseY() }, origin);
                if (rl.isKeyDown(rl.KeyboardKey.key_enter) and player.attack_timeout > 0.05) try player.shoot(&CurrentWorld, &CurrentWorld.items.items[0], mouse);

                const ox: f32 = @floatFromInt(origin[0]);
                const oy: f32 = @floatFromInt(origin[1]);

                const map_pos = rl.Vector2.init(ox, oy);
                // drawing the map itself
                rl.drawTextureEx(CurrentWorld.textures[0], map_pos, 0, scaling, color.white);
                // drawing loop for items in the world
                for (CurrentWorld.items.items) |i| {
                    if (i.image) |img| {
                        const height_offset: f32 = @floatFromInt(@divTrunc(img.height, 2));
                        const width_offset: f32 = @floatFromInt(@divTrunc(img.width, 2));
                        const pos = rl.Vector2.init((scaling * i.pos[0] + ox) - width_offset, (scaling * i.pos[1] + oy) - height_offset);
                        rl.drawTextureEx(img.*, pos, 0, scaling, color.white);
                    } else {
                        const x: i32 = @intFromFloat(i.pos[0]);
                        const y: i32 = @intFromFloat(i.pos[1]);
                        switch (i.type) {
                            .Bullet => {
                                rl.drawCircle(origin[0] + scaler(scaling, x), origin[1] + scaler(scaling, y), i.hitbox.radius, color.sky_blue);
                            },
                            else => break,
                        }
                    }
                }
            },
            .Menu => {
                const world_border = @Vector(2, i32){ scaler(scaling, preferred_width), scaler(scaling, preferred_height) };
                const origin = blk: {
                    const rw = rl.getRenderWidth();
                    const rh = rl.getRenderHeight();
                    break :blk @Vector(2, i32){ @divTrunc(rw - world_border[0], 2), @divTrunc(rh - world_border[1], 2) };
                };

                rl.drawRectangle(origin[0], origin[1], world_border[0], world_border[1], color.white);
                rl.drawText("Press space to start!", preferred_width / 2, preferred_height / 2, 20, color.dark_gray);
                if (rl.isKeyDown(rl.KeyboardKey.key_space)) {
                    state = .Level;
                    CurrentWorld = try Statemanager.loadLevel(1, gpa, images[0..]);
                    try CurrentWorld.addItem(World.CollisionType.Player, 400, 225, World.Hitbox{ .radius = 5 }, &CurrentWorld.textures[1], @Vector(2, f32){ 0, 0 });
                }
            },
        }
        rl.clearBackground(color.black);
    }
}

// all these casts suck but whatever, textures and geometric shapes render with both floats and ints
fn scaler(scale: f32, x: i32) i32 {
    const fx: f32 = @floatFromInt(x);
    const r: i32 = @intFromFloat(scale * fx);
    return r;
}

fn scaleMouse(scale: f32, m: @Vector(2, i32), origin: @Vector(2, i32)) @Vector(2, i32) {
    const mx: f32 = @floatFromInt(m[0] - origin[0]);
    const my: f32 = @floatFromInt(m[1] - origin[1]);

    const mx_i: i32 = @intFromFloat(@divTrunc(mx, scale));
    const my_i: i32 = @intFromFloat(@divTrunc(my, scale));
    return @Vector(2, i32){ mx_i, my_i };
}
