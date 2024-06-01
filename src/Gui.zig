const std = @import("std");
const rl = @import("raylib");

const Window = @import("Window.zig");
const Player = @import("Player.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");
const World = @import("World.zig");

const color = rl.Color;

const Self = @This();

pub const GuiState = enum {
    level,

    mainmenu_0,
    mainmenu_1,
};

// GUI layout
const Position = enum {
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
    elements: []GuiItem,
};

const GuiItem = union(enum) {
    ctr: Container,
    lbl: Label,
    btn: Button,
    pbr: ProgressBar,
    spc: u16,
    row: []GuiItem,
    hpm: HitpointMeter,
};

// GUI item definitions
// Basically a gui segment but with a background and label at the top
const Container = struct {
    label: Label,
    columns: u8,
    column_width: u16,
    elements: []GuiItem,
    border_color: rl.Color,
    bg_color: rl.Color,
    fg_color: rl.Color,
};

const Label = struct {
    // Label can be either image or text, or both
    image: ?*rl.Texture2D,
    text: ?[:0]const u8,
    // Use this if the text should be from somewhere else
    // I.E not hardcoded, only numerical values
    text_source: ?[:0]u8,
    fg_color: rl.Color,
};

const Button = struct {
    text: [:0]const u8,
    width: u16,
    height: u16,

    border_color: rl.Color,
    bg_color: rl.Color,
    fg_color: rl.Color,

    // This is horrible and can be done better, idk how
    action: *const fn (
        state: *Statemanager,
        textures: []rl.Texture2D,
        world: *World,
        player: *Player,
    ) anyerror!void,
};

const ProgressBar = struct {
    text: [:0]const u8,
    width: u16,
    height: u16,
    data: *u16,
    max_val: *u16,

    bg_color: rl.Color,
    fill_color: rl.Color,
    fg_color: rl.Color,
};

const HitpointMeter = struct {
    source: *u16,
    image: *rl.Texture2D,
};

pub fn reloadGui(
    gui: []GuiSegment,
    window: Window,
    mouse: ?@Vector(2, i32),
    state: *Statemanager,
    textures: []rl.Texture2D,
    world: *World,
    player: *Player,
) !void {
    for (gui) |segment| {
        // This one gets moved after each thing is drawn
        var cursor = getCursorStart(segment.pos, segment.column_width * segment.columns, window);
        // This one only for reference
        const cursorStartPoint = cursor;

        var element_id: usize = 0;
        var current_column: u16 = 0;
        while (current_column < segment.columns) : (current_column += 1) {
            cursor[0] = cursorStartPoint[0] + current_column * segment.column_width + 2 * window.gui_spacing;
            // reset the y of the cursor
            cursor[1] = cursorStartPoint[1];
            while (element_id < segment.elements.len) : (element_id += 1) {
                if (cursor[2] == 0) {
                    cursor[1] += (try drawElement(segment.elements[element_id], cursor, window, mouse, state, textures, world, player))[1];
                } else {
                    cursor[1] -= (try drawElement(segment.elements[element_id], cursor, window, mouse, state, textures, world, player))[1];
                }
            }
        }
    }
}

fn drawElement(
    element: GuiItem,
    cursor: @Vector(3, u16),
    window: Window,
    mouse: ?@Vector(2, i32),
    state: *Statemanager,
    textures: []rl.Texture2D,
    world: *World,
    player: *Player,
) !@Vector(2, u16) {
    switch (element) {
        .btn => |btn| {
            if (mouse) |m| {
                // Check if the cursor overlaps with the currently drawing button
                // Their positions are only known while being drawn
                if (m[0] > cursor[0] and m[0] < cursor[0] + btn.width)
                    if (m[1] > cursor[1] and m[1] < cursor[1] + btn.height)
                        try btn.action(state, textures, world, player);
            }
            drawObjFrame(cursor[0], cursor[1] - if (cursor[2] == 1) btn.height else 0, btn.width, btn.height, btn.bg_color, btn.border_color, window.gui_scale);
            const txt_len: i32 = @intCast(rl.measureText(btn.text, window.fontsize));
            rl.drawText(
                btn.text,
                cursor[0] + btn.width / 2 - @divTrunc(txt_len, 2),
                cursor[1] + btn.height / 2 - @divTrunc(window.fontsize, 2) - if (cursor[2] == 1) btn.height else 0,
                window.fontsize,
                btn.fg_color,
            );
            return @Vector(2, u16){ btn.width, btn.height };
        },
        .row => |row| {
            var current_height: u16 = 0;
            var local_cursorx = cursor[0];
            for (row) |item| {
                // This is the reason we need this as a vector
                // When drawing a row we care about the x, but otherwise only the y
                const item_dimensions = try drawElement(item, cursor, window, mouse, state, textures, world, player);

                current_height = @max(current_height, item_dimensions[1]);
                local_cursorx += item_dimensions[0];
            }
            return @Vector(2, u16){ local_cursorx, current_height };
        },
        .lbl => |lbl| {
            var local_cursorx = cursor[0];
            var height: u16 = 0;
            if (lbl.image) |image| {
                const w: u16 = @intCast(image.*.width);
                const h: u16 = @intCast(image.*.height);
                local_cursorx += w + window.gui_scale * window.gui_spacing;
                height = @intCast(h);
                rl.drawTextureEx(
                    image.*,
                    rl.Vector2.init(@as(f32, @floatFromInt(cursor[0])), @as(f32, @floatFromInt(cursor[1] - if (cursor[2] == 1) h else 0))),
                    0,
                    @as(f32, @floatFromInt(window.gui_scale)),
                    color.white,
                );
            }
            if (lbl.text) |text| {
                const w: u16 = @intCast(rl.measureText(text, window.fontsize));
                const h = window.fontsize;
                const height_offset: u16 = @divTrunc(height, 2) - @divTrunc(window.fontsize, 2);
                height = @max(h, height);

                rl.drawText(text, local_cursorx, cursor[1] + height_offset - if (cursor[2] == 1) h else 0, window.fontsize, lbl.fg_color);
                local_cursorx += w;
            } else if (lbl.text_source) |source| {
                const w: u16 = @intCast(rl.measureText(source, window.fontsize));
                const h = window.fontsize;
                const height_offset: u16 = @divTrunc(height, 2) - @divTrunc(window.fontsize, 2);
                height = @max(h, height);

                rl.drawText(source, local_cursorx, cursor[1] + height_offset - if (cursor[2] == 1) h else 0, window.fontsize, lbl.fg_color);
                local_cursorx += w;
            }
            return @Vector(2, u16){ local_cursorx - cursor[0], height };
        },
        .hpm => |hpm| {
            const hp = hpm.source.*;
            var local_cursorx: i32 = cursor[0];
            for (0..hp) |_| {
                rl.drawTextureEx(
                    hpm.image.*,
                    rl.Vector2.init(
                        @as(f32, @floatFromInt(local_cursorx)),
                        @as(f32, @floatFromInt(cursor[1] - if (cursor[2] == 1) @as(u16, (@intCast(hpm.image.height))) else 0)),
                    ),
                    0,
                    @as(f32, @floatFromInt(window.gui_scale)),
                    color.white,
                );
                local_cursorx += @intCast(hpm.image.*.width);
            }
            return @Vector(2, u16){ 0, @intCast(hpm.image.*.width) };
        },
        // The x here does not matter, spacers cant be in rows anyways
        .spc => |spacer| return @Vector(2, u16){ 0, spacer },
        else => return error.UnimplementedGuiComponent,
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

pub fn GuiInit(allocator: std.mem.Allocator, state: GuiState, textures: []rl.Texture2D) ![]GuiSegment {
    switch (state) {
        .level => {
            var result = try allocator.alloc(GuiSegment, 1);
            result[0] = .{
                .pos = .top_left,
                .columns = 1,
                .column_width = 400,
                .elements = undefined,
            };
            result[0].elements = try allocator.alloc(GuiItem, 3);
            result[0].elements[0] = .{ .hpm = .{
                .source = undefined,
                .image = &textures[Textures.sprite.heart],
            } };
            result[0].elements[1] = .{ .spc = 20 };
            result[0].elements[2] = .{
                .lbl = .{
                    .fg_color = color.white,
                    .image = &textures[Textures.sprite.dogecoin],
                    .text = null,
                    // Remember changing these after loading the gui
                    .text_source = null,
                },
            };
            return result;
        },

        .mainmenu_0 => {
            var result = try allocator.alloc(GuiSegment, 1);
            result[0] = .{
                .pos = .top_middle,
                .columns = 1,
                .column_width = 300,
                .elements = undefined,
            };
            result[0].elements = try allocator.alloc(GuiItem, 2);
            result[0].elements[0] = .{ .spc = 300 };
            result[0].elements[1] = .{ .btn = .{
                .text = "Start",
                .width = 300,
                .height = 50,
                .border_color = color.white,
                .bg_color = color.gray,
                .fg_color = color.black,
                .action = btn_launchGame,
            } };
            return result;
        },

        else => return error.IncorrectGuiState,
    }
}

fn btn_launchGame(state: *Statemanager, textures: []rl.Texture2D, world: *World, player: *Player) anyerror!void {
    state.*.state = .level;
    try state.*.loadLevel(1, textures, player);
    world.* = try state.*.nextRoom(textures);
}

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
