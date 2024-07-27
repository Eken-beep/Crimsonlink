const std = @import("std");
const SDL = @import("sdl2");

const Window = @import("Window.zig");
const Player = @import("Player.zig");
const Textures = @import("Textures.zig");
const Statemanager = @import("Statemanager.zig");
const World = @import("World.zig");

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
    border_color: SDL.Color,
    bg_color: SDL.Color,
    fg_color: SDL.Color,
};

const Label = struct {
    // Label can be either image or text, or both
    image: ?SDL.Texture,
    text: ?*Text,
    // Use this if the text should be from somewhere else
    // I.E not hardcoded into the init function
    text_source: ?[:0]u8,
    fg_color: SDL.Color,
};

const Button = struct {
    text: *Text,
    width: u16 = 300,
    height: u16 = 50,

    border_color: SDL.Color = SDL.Color.white,
    bg_color: SDL.Color = SDL.Color.rgb(50, 50, 50),
    fg_color: SDL.Color = SDL.Color.black,

    // This is horrible and can be done better, idk how
    action: *const fn (
        state: *Statemanager,
        r: *SDL.Renderer,
        font: SDL.ttf.Font,
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

    bg_color: SDL.Color,
    fill_color: SDL.Color,
    fg_color: SDL.Color,
};

const HitpointMeter = struct {
    source: *u16,
    image: SDL.Texture,
};

const InventorySlot = struct {
    slot_source: *?Player.Item,
    id: usize,
    text: *Text,
};

pub const Text = struct {
    // Absolute waste of space
    stored_str: [100]u8 = std.mem.zeroes([100]u8),
    str_len: usize = undefined,
    texture: SDL.Texture = undefined,
    size: SDL.Size = undefined,

    pub fn draw(self: *@This(), r: *SDL.Renderer, rect: SDL.Rectangle) error{SdlError}!void {
        try r.copy(self.texture, rect, null);
    }

    pub fn update(self: *@This(), new_str: []const u8, r: *SDL.Renderer, font: SDL.ttf.Font, color: SDL.Color) error{ SdlError, TtfError, NoSpaceLeft }!void {
        if (!std.mem.eql(u8, new_str, self.stored_str[0..self.str_len :0])) {
            std.mem.copyForwards(u8, &self.stored_str, new_str);
            self.str_len = new_str.len;

            self.texture.destroy();
            const txt_surface = try font.renderTextSolid(self.stored_str[0..new_str.len :0], color);
            self.texture = try SDL.createTextureFromSurface(r.*, txt_surface);

            self.size = font.sizeText(self.stored_str[0..new_str.len :0]) catch blk: {
                const fallback_size: c_int = @intCast(28 * new_str.len);
                std.log.warn("Could not calculate size of string {s} with current font falling back to size {d}", .{
                    new_str,
                    fallback_size,
                });
                break :blk SDL.Size{ .width = fallback_size, .height = 28 };
            };
        }
    }

    pub fn init(str: []const u8, r: *SDL.Renderer, font: SDL.ttf.Font, color: SDL.Color) error{ SdlError, TtfError, NoSpaceLeft }!@This() {
        var result = @This(){ .str_len = str.len };

        std.mem.copyForwards(u8, &result.stored_str, str);

        const txt_surface = try font.renderTextSolid(result.stored_str[0..str.len :0], color);
        result.texture = try SDL.createTextureFromSurface(r.*, txt_surface);

        result.size = font.sizeText(result.stored_str[0..str.len :0]) catch blk: {
            const fallback_size: c_int = @intCast(28 * str.len);
            std.log.warn("Could not calculate size of string {s} with current font falling back to size {d}", .{
                str,
                fallback_size,
            });
            break :blk SDL.Size{ .width = fallback_size, .height = 28 };
        };
        return result;
    }
};

pub fn reloadGui(
    r: *SDL.Renderer,
    font: SDL.ttf.Font,
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
                    r,
                    font,
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
    r: *SDL.Renderer,
    font: SDL.ttf.Font,
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
                        std.log.info("Clicked a button: {s}", .{btn.text.*.stored_str[0..]});
                        try btn.action(state, r, font, textures, world, player);
                    };

            try drawObjFrame(
                r,
                cursor[0],
                cursor[1] - if (cursor[2] == 1) btn.height else 0,
                btn.width,
                btn.height,
                btn.bg_color,
                btn.border_color,
                window.gui_scale,
            );

            try btn.text.*.draw(r, .{
                .x = cursor[0] + @divTrunc(@as(c_int, btn.width), 2) - @divTrunc(btn.text.*.size.width, 2),
                .y = cursor[1] + @divTrunc(@as(c_int, btn.height), 2) - @divTrunc(btn.text.*.size.height, 2) - @as(c_int, cursor[2] * btn.height),
                .width = btn.text.*.size.width,
                .height = btn.text.*.size.height,
            });

            return @Vector(2, u16){ btn.width, btn.height + window.gui_spacing };
        },
        .row => |row| {
            var current_height: u16 = 0;
            var local_cursorx = cursor[0];
            for (row) |item| {
                // This is the reason we need this as a vector
                // When drawing a row we care about the x, but otherwise only the y
                const item_dimensions = try drawElement(
                    r,
                    font,
                    item,
                    cursor,
                    window,
                    mouse,
                    state,
                    textures,
                    world,
                    player,
                );

                current_height = @max(current_height, item_dimensions[1]);
                local_cursorx += item_dimensions[0];
            }
            return @Vector(2, u16){ local_cursorx, current_height };
        },
        .lbl => |lbl| {
            var local_cursorx = cursor[0] + window.gui_spacing * window.gui_scale;
            var height: u16 = 0;
            if (lbl.image) |image| {
                const info = try image.query();
                height = info.height;
                local_cursorx += info.width + window.gui_scale * window.gui_spacing;

                try r.copy(image, .{
                    .x = cursor[0],
                    .y = cursor[1] - cursor[2] * info.height,
                    .width = info.width,
                    .height = info.height,
                }, null);
            }
            if (lbl.text) |*text| {
                if (lbl.text_source) |source| {
                    try text.*.update(source, r, font, lbl.fg_color);
                }
                const height_offset: c_int = @divTrunc(height, 2) - @divTrunc(text.*.size.height, 2);
                try text.*.draw(r, .{
                    .x = local_cursorx,
                    .y = cursor[1] + height_offset - cursor[2] * text.*.size.height,
                    .width = text.*.size.width,
                    .height = text.*.size.height,
                });
                //local_cursorx += @intCast(size.width);
            }
            return @Vector(2, u16){ local_cursorx - cursor[0], height };
        },
        .hpm => |hpm| {
            const hp = hpm.source.*;
            var local_cursorx: u16 = cursor[0];
            const info = try hpm.image.query();
            for (0..hp) |_| {
                try r.copy(hpm.image, .{ .x = local_cursorx, .y = cursor[1] - cursor[2] * info.height, .width = info.width, .height = info.height }, null);
                local_cursorx += info.width + window.gui_spacing;
            }
            return @Vector(2, u16){ @intCast(info.width * hpm.source.*), @intCast(info.height) };
        },
        .inventory_slot => |slot| {
            // Temporary as we don't have a texture for this yet
            const rect = SDL.Rectangle{ .x = cursor[0], .y = cursor[1] - 80, .width = 80, .height = 80 };
            try r.setColorRGB(0, 0, 0);
            try r.drawRect(rect);

            if (slot.slot_source.*) |item| {
                try r.copy(item.image, rect, null);
                var text_buffer = [3:0]u8{ ' ', ' ', ' ' };
                _ = try std.fmt.bufPrint(&text_buffer, "{d: <3}", .{item.ammount});
                try slot.text.*.update(&text_buffer, r, font, SDL.Color.black);
                try slot.text.*.draw(r, .{
                    .x = cursor[0] + 10 * window.gui_scale,
                    .y = cursor[1] + 10 * window.gui_scale - cursor[2] * 80,
                    .width = slot.text.*.size.width,
                    .height = slot.text.*.size.height,
                });
            }
            return @Vector(2, u16){ 80, 80 + window.gui_spacing * window.gui_scale };
        },
        // The x here does not matter, spacers cant be in rows anyways
        .spc => |spacer| return @Vector(2, u16){ 0, spacer },
        .columnbreak => return ElementDrawError.ColumnBreak,
        else => return ElementDrawError.UnimplementedGuiComponent,
    }
}

fn drawObjFrame(r: *SDL.Renderer, x: u16, y: u16, w: u16, h: u16, bgc: SDL.Color, bc: SDL.Color, scale: u8) error{SdlError}!void {
    try r.setColor(bc);
    try r.fillRect(.{ .x = x - 2 * scale, .y = y - 2 * scale, .width = w + 4 * scale, .height = h + 4 * scale });
    try r.setColor(bgc);
    try r.fillRect(.{ .x = x, .y = y, .width = w, .height = h });
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
const GuiInitError = error{ SdlError, TtfError, OutOfMemory, IncorrectGuiState, NoSpaceLeft };
pub fn GuiInit(allocator: std.mem.Allocator, state: GuiState, textures: Textures.TextureMap, r: *SDL.Renderer, font: SDL.ttf.Font) GuiInitError![]GuiSegment {
    std.log.info("Loaded gui state {any}", .{state});
    switch (state) {
        .level => {
            var result = try allocator.alloc(GuiSegment, 2);
            result[0] = .{
                .pos = .top_left,
                .columns = 1,
                .column_width = 400,
                .elements = undefined,
            };
            result[0].elements = try allocator.alloc(GuiItem, 5);
            result[0].elements[0] = .{ .hpm = .{
                .source = undefined,
                .image = Textures.getTexture(textures, "heart").single,
            } };
            result[0].elements[1] = .{ .spc = 20 };
            // The whole reason this is heap allocated is because I can't figure out why it coerces to a const otherwise
            const text1 = try allocator.create(Text);
            text1.* = try Text.init(" ", r, font, SDL.Color.black);
            result[0].elements[2] = .{ .lbl = .{
                .fg_color = SDL.Color.white,
                .image = null,
                .text = text1,
                .text_source = null,
            } };
            result[0].elements[3] = .{ .spc = 20 };
            const text2 = try allocator.create(Text);
            text2.* = try Text.init(" ", r, font, SDL.Color.black);
            result[0].elements[4] = .{
                .lbl = .{
                    .fg_color = SDL.Color.white,
                    .image = Textures.getTexture(textures, "doge").single,
                    .text = text2,
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
                const text = try allocator.create(Text);
                text.* = try Text.init(" ", r, font, SDL.Color.black);
                element.* = .{ .inventory_slot = .{
                    .id = i,
                    .slot_source = undefined,
                    .text = text,
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
            const text1 = try allocator.create(Text);
            text1.* = try Text.init("Start", r, font, SDL.Color.black);
            result[0].elements[1] = .{ .btn = .{
                .text = text1,
                .action = btn_launchGame,
            } };
            const text2 = try allocator.create(Text);
            text2.* = try Text.init("Settings", r, font, SDL.Color.black);
            result[0].elements[2] = .{ .btn = .{
                .text = text2,
                .action = btn_setState_settings,
            } };
            const text3 = try allocator.create(Text);
            text3.* = try Text.init("Quit", r, font, SDL.Color.black);
            result[0].elements[3] = .{ .btn = .{
                .text = text3,
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
            const text1 = try allocator.create(Text);
            text1.* = try Text.init("Paused", r, font, SDL.Color.black);
            result[0].elements[0] = .{ .lbl = .{
                .fg_color = SDL.Color.rgb(50, 50, 50),
                .image = null,
                .text_source = null,
                .text = text1,
            } };

            // Main buttons
            result[1] = .{
                .pos = .top_middle,
                .columns = 1,
                .column_width = 300,
                .elements = try allocator.alloc(GuiItem, 4),
            };
            result[1].elements[0] = .{ .spc = 300 };
            const text2 = try allocator.create(Text);
            text2.* = try Text.init("Resume", r, font, SDL.Color.black);
            result[1].elements[1] = .{ .btn = .{
                .text = text2,
                .action = btn_unpauseGame,
            } };
            const text3 = try allocator.create(Text);
            text3.* = try Text.init("Settings", r, font, SDL.Color.black);
            result[1].elements[2] = .{ .btn = .{
                .text = text3,
                .action = btn_setState_settings,
            } };
            const text4 = try allocator.create(Text);
            text4.* = try Text.init("Quit Game", r, font, SDL.Color.black);
            result[1].elements[3] = .{ .btn = .{
                .text = text4,
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
            const text1 = try allocator.create(Text);
            text1.* = try Text.init("Fullscreen", r, font, SDL.Color.black);
            result[0].elements[1] = .{ .btn = .{
                .text = text1,
                .action = btn_setting_fullscreen,
            } };

            // Column 2
            result[0].elements[2] = .{ .spc = 300 };
            const text2 = try allocator.create(Text);
            text2.* = try Text.init("Back", r, font, SDL.Color.black);
            result[0].elements[3] = .{ .btn = .{
                .text = text2,
                .action = btn_loadParentState,
            } };
            const text3 = try allocator.create(Text);
            text3.* = try Text.init("Placeholder", r, font, SDL.Color.black);
            result[0].elements[4] = .{ .lbl = .{
                .fg_color = SDL.Color.rgb(50, 50, 50),
                .image = null,
                .text_source = null,
                .text = text3,
            } };

            return result;
        },

        else => return GuiInitError.IncorrectGuiState,
    }
}

fn btn_launchGame(state: *Statemanager, r: *SDL.Renderer, _: SDL.ttf.Font, textures: Textures.TextureMap, world: *World, player: *Player) !void {
    state.*.state = .level;
    // Note about this
    // The ram has to be freed in the main function by setting the
    // halt_gui_rendering variable of the state
    try state.*.loadLevel(r, 1, textures, player, world);
    state.halt_gui_rendering = true;
}
fn btn_unpauseGame(state: *Statemanager, r: *SDL.Renderer, font: SDL.ttf.Font, textures: Textures.TextureMap, world: *World, player: *Player) !void {
    try state.pauseLevel(world, textures, player, r, font);
}
fn btn_quitGame(state: *Statemanager, _: *SDL.Renderer, _: SDL.ttf.Font, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.state = .exit_game;
    // For some reason closing the window here makes the program segfault
    //rl.closeWindow();
}

fn btn_loadParentState(state: *Statemanager, _: *SDL.Renderer, _: SDL.ttf.Font, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_state = state.gui_parent_state;
    state.gui_parent_state = .none;
    state.halt_gui_rendering = true;
}
fn btn_setState_settings(state: *Statemanager, _: *SDL.Renderer, _: SDL.ttf.Font, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_parent_state = state.gui_state;
    state.gui_state = .settings_main;
    state.halt_gui_rendering = true;
}
fn btn_setState_mainMenu(state: *Statemanager, _: *SDL.Renderer, _: SDL.ttf.Font, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_state = .mainmenu_0;
    state.halt_gui_rendering = true;
}
fn btn_setState_levelPaused(state: *Statemanager, _: *SDL.Renderer, _: SDL.ttf.Font, _: Textures.TextureMap, _: *World, _: *Player) !void {
    state.gui_state = .level_paused;
    state.halt_gui_rendering = true;
}
fn btn_setting_fullscreen(_: *Statemanager, _: *SDL.Renderer, _: SDL.ttf.Font, _: Textures.TextureMap, _: *World, _: *Player) !void {
    //if (rl.isWindowState(.{ .fullscreen_mode = true })) {
    //    rl.setWindowState(.{ .fullscreen_mode = false, .window_resizable = true });
    //} else {
    //    rl.setWindowState(.{ .fullscreen_mode = true, .window_resizable = false });
    //}
}
