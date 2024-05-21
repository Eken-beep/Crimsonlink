const std = @import("std");
const rl = @import("raylib");

const Window = @import("Window.zig");
const Player = @import("Player.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");
const World = @import("World.zig");

// GUI layout
pub const Position = enum {
    // Stack the gui elements from the sort order
    top_left,
    top_middle,
    top_right,

    bottom_left,
    bottom_middle,
    bottom_right,
};

pub const GuiSegment = struct {
    pos: Position,
    columns: u8,
    // This is the width of the largest element in the gui
    column_width: u16,
    elements: []const GuiItem,
};

pub const GuiItem = union(enum) {
    ctr: Container,
    lbl: Label,
    btn: Button,
    pbr: ProgressBar,
    spc: u16,
};

// GUI item definitions
// Basically a gui segment but with a background and label at the top
pub const Container = struct {
    label: Label,
    columns: u8,
    column_width: u16,
    elements: []GuiItem,
    border_color: rl.Color,
    bg_color: rl.Color,
    fg_color: rl.Color,
};

pub const Label = struct {
    text: [:0]const u8,
    fg_color: rl.Color,
};

pub const Button = struct {
    text: [:0]const u8,
    width: u16,
    height: u16,

    border_color: rl.Color,
    bg_color: rl.Color,
    fg_color: rl.Color,

    // This is horribly sloppy and can be done better, idk how
    action: *const fn (state: *Statemanager, textures: []rl.Texture2D, world: *World) anyerror!void,
};

pub const ProgressBar = struct {
    text: [:0]const u8,
    width: u16,
    height: u16,
    data: *u16,

    bg_color: rl.Color,
    fill_color: rl.Color,
    fg_color: rl.Color,
};

pub fn reloadGui(
    gui: []const GuiSegment,
    window: Window,
    mouse: ?@Vector(2, i32),
    state: *Statemanager,
    textures: []rl.Texture2D,
    world: *World,
) !void {
    for (gui) |segment| {
        // This one gets moved after each thing is drawn
        var cursor = getCursorStart(segment.pos, segment.column_width * segment.columns, window);
        // This one only for reference
        const cursorStartPoint = cursor;

        var current_column: u16 = 0;
        while (current_column < segment.columns) : (current_column += 1) {
            cursor[0] = cursorStartPoint[0] + current_column * segment.column_width + 2 * window.gui_spacing;
            // reset the y of the cursor
            cursor[1] = cursorStartPoint[1];
            for (segment.elements) |element| {
                switch (element) {
                    .btn => |btn| {
                        if (mouse) |m| {
                            // Check if the cursor overlaps with the currently drawing button
                            // Their positions are only known while being drawn
                            if (m[0] > cursor[0] and m[0] < cursor[0] + btn.width)
                                if (m[1] > cursor[1] and m[1] < cursor[1] + btn.height)
                                    try btn.action(state, textures, world);
                        }
                        drawObjFrame(cursor[0], cursor[1], btn.width, btn.height, btn.bg_color, btn.border_color, window.gui_scale);
                        const txt_len: i32 = @intCast(rl.measureText(btn.text, window.fontsize));
                        rl.drawText(
                            btn.text,
                            cursor[0] + btn.width / 2 - @divTrunc(txt_len, 2),
                            cursor[1] + btn.height / 2 - @divTrunc(window.fontsize, 2),
                            window.fontsize,
                            btn.fg_color,
                        );
                        cursor[1] += btn.height;
                    },
                    .spc => |spacer| cursor[1] += spacer,
                    else => {},
                }
            }
        }
    }
}

fn drawObjFrame(x: u16, y: u16, w: u16, h: u16, bgc: rl.Color, bc: rl.Color, scale: u8) void {
    rl.drawRectangle(x - 2 * scale, y - 2 * scale, w + 4 * scale, h + 4 * scale, bc);
    rl.drawRectangle(x, y, w, h, bgc);
}

// The third item in the vector sets the sort order, bottom up or top down
// 0 => top-down 1 => bottom-up
fn getCursorStart(pos: Position, column_size: u16, window: Window) @Vector(3, u16) {
    return switch (pos) {
        .top_left => @Vector(3, u16){
            window.gui_spacing,
            window.gui_spacing,
            0,
        },
        .top_middle => @Vector(3, u16){
            @divTrunc(window.width, 2) - @divTrunc(column_size, 2),
            window.gui_spacing,
            0,
        },
        .top_right => @Vector(3, u16){
            window.width - column_size - window.gui_spacing,
            window.gui_spacing,
            0,
        },

        .bottom_left => @Vector(3, u16){
            window.gui_spacing,
            window.height - window.gui_spacing,
            1,
        },
        .bottom_middle => @Vector(3, u16){
            @divTrunc(window.width, 2) - @divTrunc(column_size, 2),
            window.height - window.gui_spacing,
            1,
        },
        .bottom_right => @Vector(3, u16){
            window.width - column_size - window.gui_spacing,
            window.height - window.gui_spacing,
            1,
        },
    };
}

// What we have here is the following
// GuiSegment contains a position on the screen which the draw function takes along with the number of columns and items
// and then puts a cursor on that position and begins drawing everything from there, dividing len(elements) by columns to figure
// out when we need to break the line and begin the next one, useful in menus and stuff

// This is gonna go to hell when i'm done with the proper gui thing
pub fn drawLevelGui(window: Window, textures: []rl.Texture2D, player: Player) !void {
    const s = window.scale;

    // HP
    for (0..player.hp) |i| {
        const fi: f32 = @floatFromInt(i);
        rl.drawTextureEx(textures[Textures.sprite.heart], rl.Vector2.init((10 + 90 * fi) * s, 10 * s), 0, s, rl.Color.white);
    }

    // Money
    rl.drawTextureEx(
        textures[Textures.sprite.dogecoin],
        rl.Vector2.init(10 * s, 20 * s + @as(f32, @floatFromInt(textures[Textures.sprite.heart].height)) * s),
        0,
        s * 0.5,
        rl.Color.white,
    );
    var coin_buffer: [3:0]u8 = undefined;
    rl.drawText(
        try std.fmt.bufPrintZ(&coin_buffer, "{d}", .{player.inventory.dogecoins}),
        @as(i32, @intFromFloat(10 * s)) + @divFloor(textures[Textures.sprite.dogecoin].height, 2),
        @as(i32, @intFromFloat(@as(f32, @floatFromInt(textures[Textures.sprite.heart].height)) * s + 30 * s)),
        28,
        rl.Color.gray,
    );
}
