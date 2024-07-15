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
    none,
    level,
    level_paused,

    mainmenu_0,

    settings_main,
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
    columnbreak,
    ctr: Container,
    lbl: Label,
    btn: Button,
    pbr: ProgressBar,
    spc: u16,
    row: []GuiItem,
    hpm: HitpointMeter,
    inventory_slot: InventorySlot,
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
    image: ?rl.Texture2D,
    text: ?[:0]const u8,
    // Use this if the text should be from somewhere else
    // I.E not hardcoded, only numerical values
    text_source: ?[:0]u8,
    fg_color: rl.Color,
};

const Button = struct {
    text: [:0]const u8,
    width: u16 = 300,
    height: u16 = 50,

    border_color: rl.Color = color.white,
    bg_color: rl.Color = color.gray,
    fg_color: rl.Color = color.black,

    // This is horrible and can be done better, idk how
    action: *const fn (
        state: *Statemanager,
        textures: Textures.TextureMap,
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
    image: rl.Texture2D,
};

const InventorySlot = struct {
    slot_source: *?Player.Item,
    id: usize,
};

pub fn reloadGui(
    gui: []GuiSegment,
    window: Window,
    mouse: ?@Vector(2, i32),
    state: *Statemanager,
    textures: Textures.TextureMap,
    world: *World,
    player: *Player,
) !void {
    for (gui) |segment| {
        // This one gets moved after each thing is drawn
        var cursor = getCursorStart(segment.pos, (segment.column_width + window.gui_spacing) * segment.columns, window);
        // This one only for reference
        const cursorStartPoint = cursor;

        var element_id: usize = 0;
        var current_column: u16 = 0;
        columnLoop: while (current_column < segment.columns) : (current_column += 1) {
            cursor[0] = cursorStartPoint[0] + current_column * (segment.column_width + 2 * window.gui_spacing);
            // reset the y of the cursor
            cursor[1] = cursorStartPoint[1];
            while (element_id < getLastElementInColumn(
                segment.elements.len,
                segment.columns,
                current_column,
            )) : (element_id += 1) {
                const element_size = drawElement(
                    segment.elements[element_id],
                    cursor,
                    window,
                    mouse,
                    state,
                    textures,
                    world,
                    player,
                ) catch |err| switch (err) {
                    // Abuse of errors
                    ElementDrawError.ColumnBreak => {
                        current_column += 1;
                        element_id += 1;
                        continue :columnLoop;
                    },
                    else => return err,
                };
                if (cursor[2] == 0) {
                    cursor[1] += element_size[1];
                } else {
                    cursor[1] -= element_size[1];
                }
            }
        }
    }
}

// This is perhaphs too primitive as it only supports having all the overflowing elements on the end of the last row
fn getLastElementInColumn(nr_elements: usize, nr_columns: usize, current_column: usize) usize {
    const elements_per_column = nr_elements / nr_columns;
    if (current_column == nr_columns - 1) {
        return nr_elements;
    } else {
        return (current_column + 1) * elements_per_column;
    }
}

const ElementDrawError = error{
    UnimplementedGuiComponent,
    InvalidColumnLayout,
    ColumnBreak,
};

fn drawElement(
    element: GuiItem,
    cursor: @Vector(3, u16),
    window: Window,
    mouse: ?@Vector(2, i32),
    state: *Statemanager,
    textures: Textures.TextureMap,
    world: *World,
    player: *Player,
    // Due to the definition of the button action function this has to be an inferred error
) !@Vector(2, u16) {
    switch (element) {
        .btn => |btn| {
            if (mouse) |m|
                // Check if the cursor overlaps with the currently drawing button
                // Their positions are only known while being drawn
                if (m[0] > cursor[0] and m[0] < cursor[0] + btn.width)
                    if (m[1] > cursor[1] and m[1] < cursor[1] + btn.height) {
                        std.debug.print("Clicked a button: {s}\n", .{btn.text});
                        try btn.action(state, textures, world, player);
                    };

            drawObjFrame(cursor[0], cursor[1] - if (cursor[2] == 1) btn.height else 0, btn.width, btn.height, btn.bg_color, btn.border_color, window.gui_scale);
            const txt_len: i32 = @intCast(rl.measureText(btn.text, window.fontsize));
            rl.drawText(
                btn.text,
                cursor[0] + btn.width / 2 - @divTrunc(txt_len, 2),
                cursor[1] + btn.height / 2 - @divTrunc(window.fontsize, 2) - cursor[2] * btn.height,
                window.fontsize,
                btn.fg_color,
            );
            return @Vector(2, u16){ btn.width, btn.height + window.gui_spacing };
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
            var local_cursorx = cursor[0] + window.gui_spacing * window.gui_scale;
            var height: u16 = 0;
            if (lbl.image) |image| {
                const w: u16 = @intCast(image.width);
                const h: u16 = @intCast(image.height);
                local_cursorx += w + window.gui_scale * window.gui_spacing;
                height = @intCast(h);
                rl.drawTextureEx(
                    image,
                    rl.Vector2.init(@as(f32, @floatFromInt(cursor[0])), @as(f32, @floatFromInt(cursor[1] - cursor[2] * h))),
                    0,
                    @as(f32, @floatFromInt(window.gui_scale)),
                    color.white,
                );
            }
            if (lbl.text) |text| {
                const w: u16 = @intCast(rl.measureText(text, window.fontsize));
                const h = window.fontsize;
                height = @max(h, height);
                const height_offset: u16 = @divTrunc(height, 2) - @divTrunc(window.fontsize, 2);

                rl.drawText(text, local_cursorx, cursor[1] + height_offset - cursor[2] * h, window.fontsize, lbl.fg_color);
                local_cursorx += w;
            } else if (lbl.text_source) |source| {
                const w: u16 = @intCast(rl.measureText(source, window.fontsize));
                const h = window.fontsize;
                height = @max(h, height);
                const height_offset: u16 = @divTrunc(height, 2) - @divTrunc(window.fontsize, 2);

                rl.drawText(source, local_cursorx, cursor[1] + height_offset - cursor[2] * h, window.fontsize, lbl.fg_color);
                local_cursorx += w;
            }
            return @Vector(2, u16){ local_cursorx - cursor[0], height };
        },
        .hpm => |hpm| {
            const hp = hpm.source.*;
            var local_cursorx: i32 = cursor[0];
            for (0..hp) |_| {
                rl.drawTextureEx(
                    hpm.image,
                    rl.Vector2.init(
                        @as(f32, @floatFromInt(local_cursorx)),
                        @as(f32, @floatFromInt(cursor[1] - cursor[2] * hpm.image.height)),
                    ),
                    0,
                    @as(f32, @floatFromInt(window.gui_scale)),
                    color.white,
                );
                local_cursorx += @intCast(hpm.image.width);
            }
            return @Vector(2, u16){ @intCast(hpm.image.width * hpm.source.*), @intCast(hpm.image.height) };
        },
        .inventory_slot => |slot| {
            rl.drawRectangleLines(cursor[0], cursor[1] - 80, 80, 80, color.gray);
            if (slot.slot_source.*) |item| {
                rl.drawTexture(item.image, cursor[0], cursor[1] - 80, color.white);
                var text_buffer = [3:0]u8{ ' ', ' ', ' ' };
                _ = try std.fmt.bufPrint(&text_buffer, "{d: <3}", .{item.ammount});
                rl.drawText(&text_buffer, cursor[0] + 10, cursor[1] + 10 - 80, window.fontsize, color.dark_gray);
            }
            return @Vector(2, u16){ 80, 80 + window.gui_spacing * window.gui_scale };
        },
        // The x here does not matter, spacers cant be in rows anyways
        .spc => |spacer| return @Vector(2, u16){ 0, spacer },
        .columnbreak => return ElementDrawError.ColumnBreak,
        else => return ElementDrawError.UnimplementedGuiComponent,
    }
}

fn drawObjFrame(x: u16, y: u16, w: u16, h: u16, bgc: rl.Color, bc: rl.Color, scale: u8) void {
    rl.drawRectangle(x - 2 * scale, y - 2 * scale, w + 4 * scale, h + 4 * scale, bc);
    rl.drawRectangle(x, y, w, h, bgc);
}

// The third item in the vector sets the sort order, bottom up or top down
// 0 => top-down 1 => bottom-up

// TODO the right and middle sorting buttons don't start in the correct position,
// should start based on not only the cursor but also the element size
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
const GuiInitError = error{ OutOfMemory, IncorrectGuiState };
pub fn GuiInit(allocator: std.mem.Allocator, state: GuiState, textures: Textures.TextureMap) GuiInitError![]GuiSegment {
    std.debug.print("Loaded gui state {any}\n", .{state});
    switch (state) {
        .level => {
            var result = try allocator.alloc(GuiSegment, 2);
            result[0] = .{
                .pos = .top_left,
                .columns = 1,
                .column_width = 400,
                .elements = undefined,
            };
            result[0].elements = try allocator.alloc(GuiItem, 3);
            result[0].elements[0] = .{ .hpm = .{
                .source = undefined,
                .image = Textures.getTexture(textures, "heart").single,
            } };
            result[0].elements[1] = .{ .spc = 20 };
            result[0].elements[2] = .{
                .lbl = .{
                    .fg_color = color.white,
                    .image = Textures.getTexture(textures, "doge").single,
                    .text = null,
                    // Remember changing these after loading the gui
                    .text_source = null,
                },
            };

            // The hotbar
            result[1] = .{
                .pos = .bottom_left,
                .columns = 1,
                .column_width = 50,
                .elements = try allocator.alloc(GuiItem, 4),
            };
            for (result[1].elements, 0..) |*element, i| {
                element.* = .{ .inventory_slot = .{
                    .id = i,
                    .slot_source = undefined,
                } };
            }
            return result;
        },

        .mainmenu_0 => {
            var result = try allocator.alloc(GuiSegment, 1);
            result[0] = .{
                .pos = .top_middle,
                .columns = 1,
                .column_width = 300,
                .elements = try allocator.alloc(GuiItem, 4),
            };
            result[0].elements[0] = .{ .spc = 300 };
            result[0].elements[1] = .{ .btn = .{
                .text = "Start",
                .action = btn_launchGame,
            } };
            result[0].elements[2] = .{ .btn = .{
                .text = "Settings",
                .action = btn_setState_settings,
            } };
            result[0].elements[3] = .{ .btn = .{
                .text = "Quit",
                .action = btn_quitGame,
            } };

            return result;
        },

        .level_paused => {
            var result = try allocator.alloc(GuiSegment, 2);
            // Pause text
            result[0] = .{
                .pos = .bottom_right,
                .columns = 1,
                .column_width = 130,
                .elements = try allocator.alloc(GuiItem, 1),
            };
            result[0].elements[0] = .{ .lbl = .{
                .fg_color = color.gray,
                .image = null,
                .text_source = null,
                .text = "Paused",
            } };

            // Main buttons
            result[1] = .{
                .pos = .top_middle,
                .columns = 1,
                .column_width = 300,
                .elements = try allocator.alloc(GuiItem, 4),
            };
            result[1].elements[0] = .{ .spc = 300 };
            result[1].elements[1] = .{ .btn = .{
                .text = "Resume Game",
                .action = btn_unpauseGame,
            } };
            result[1].elements[2] = .{ .btn = .{
                .text = "Settings",
                .action = btn_setState_settings,
            } };
            result[1].elements[3] = .{ .btn = .{
                .text = "Quit game",
                .action = btn_quitGame,
            } };
            return result;
        },

        .settings_main => {
            var result = try allocator.alloc(GuiSegment, 1);
            result[0] = .{
                .pos = .top_middle,
                .columns = 2,
                .column_width = 300,
                .elements = try allocator.alloc(GuiItem, 5),
            };

            // Column 1
            result[0].elements[0] = .{ .spc = 300 };
            result[0].elements[1] = .{ .btn = .{
                .text = "Fullscreen",
                .action = btn_setting_fullscreen,
            } };

            // Column 2
            result[0].elements[2] = .{ .spc = 300 };
            result[0].elements[3] = .{ .btn = .{
                .text = "Back",
                .action = btn_loadParentState,
            } };
            result[0].elements[4] = .{ .lbl = .{
                .fg_color = color.gray,
                .image = null,
                .text_source = null,
                .text = "placeholder",
            } };

            return result;
        },

        else => return GuiInitError.IncorrectGuiState,
    }
}

fn btn_launchGame(state: *Statemanager, textures: Textures.TextureMap, world: *World, player: *Player) !void {
    state.*.state = .level;
    // Note about this
    // The ram has to be freed in the main function by setting the
    // halt_gui_rendering variable of the state
    try state.*.loadLevel(1, textures, player, world);
    state.halt_gui_rendering = true;
}
fn btn_unpauseGame(state: *Statemanager, textures: Textures.TextureMap, world: *World, player: *Player) !void {
    try state.pauseLevel(world, textures, player);
}
fn btn_quitGame(state: *Statemanager, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.state = .exit_game;
    // For some reason closing the window here makes the program segfault
    //rl.closeWindow();
}

fn btn_loadParentState(state: *Statemanager, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_state = state.gui_parent_state;
    state.gui_parent_state = .none;
    state.halt_gui_rendering = true;
}
fn btn_setState_settings(state: *Statemanager, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_parent_state = state.gui_state;
    state.gui_state = .settings_main;
    state.halt_gui_rendering = true;
}
fn btn_setState_mainMenu(state: *Statemanager, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_state = .mainmenu_0;
    state.halt_gui_rendering = true;
}
fn btn_setState_levelPaused(state: *Statemanager, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_state = .level_paused;
    state.halt_gui_rendering = true;
}
fn btn_setting_fullscreen(_: *Statemanager, _: Textures.TextureMap, _: *World, _: *Player) !void {
    if (rl.isWindowState(.{ .fullscreen_mode = true })) {
        rl.setWindowState(.{ .fullscreen_mode = false, .window_resizable = true });
    } else {
        rl.setWindowState(.{ .fullscreen_mode = true, .window_resizable = false });
    }
}
