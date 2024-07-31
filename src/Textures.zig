const std = @import("std");
const SDL = @import("sdl2");

const World = @import("World.zig");
const fs = std.fs;

const DRAW_HITBOXES = true;

pub const TextureMap = std.StringArrayHashMap(TextureStore);
const pi = std.math.pi;

pub const Animation = struct {
    const Anim = @This();

    nr_frames: u8,
    current_frame: u8 = 0,

    frametime: f32,
    timer: f32 = 0,
    frames: []AnimationData,
    direction: u8 = 0,
    direction_rad: f32 = 0,
    avalilable_directions: u8 = 1,
    previous_velocity: @Vector(2, f32) = @splat(0),

    pub fn step(anim: *Anim, dt: f32, state: World.State) void {
        anim.timer += dt;
        if (anim.timer > anim.frametime) {
            anim.timer = 0;
            anim.current_frame += 1;

            const direction_frames = anim.frames[anim.direction].get(state);

            switch (direction_frames) {
                .slice => {
                    if (anim.current_frame == direction_frames.slice.len) anim.current_frame = 0;
                },
                .single => anim.current_frame = 0,
            }
        }
    }

    pub fn getFrame(
        anim: *Anim,
        v: @Vector(2, f32),
        state: World.State,
    ) SDL.Texture {
        const angle: f32 = std.math.atan2(v[1], v[0]);
        var direction: ?usize = null;

        if (state == .walking and !@reduce(.Or, v != anim.previous_velocity)) {
            // Calculate the value here and approximate it to one of the 8 possible directions
            direction = switch (anim.avalilable_directions) {
                8 => blk: {
                    const directions = [_]f32{
                        pi / 2.0,
                        pi / 4.0,
                        0,
                        -pi / 4.0,
                        -pi / 2.0,
                        -3 * pi / 4.0,
                        pi,
                        3 * pi / 4.0,
                    };
                    var closest: f32 = directions[0];
                    for (directions) |d| {
                        if (@abs(d - angle) < @abs(closest - angle)) closest = d;
                    }
                    anim.direction_rad = closest;
                    for (directions, 0..) |d, i| {
                        if (d == closest) {
                            break :blk i;
                        }
                    } else break :blk null;
                },
                4 => blk: {
                    const directions = [_]f32{
                        -pi / 2.0,
                        0,
                        pi / 2.0,
                        pi,
                    };
                    var closest: f32 = directions[0];
                    for (directions) |d| {
                        if (@abs(d - angle) < @abs(closest - angle)) closest = d;
                    }
                    anim.direction_rad = closest;
                    for (directions, 0..) |d, i| {
                        if (d == closest) break :blk i;
                    } else break :blk null;
                },
                2 => blk: {
                    const directions = [_]f32{
                        0,
                        pi,
                    };
                    var closest: f32 = directions[0];
                    for (directions) |d| {
                        if (@abs(d - angle) < @abs(closest - angle)) closest = d;
                    }
                    anim.direction_rad = closest;
                    for (directions, 0..) |d, i| {
                        if (d == closest) break :blk i;
                    } else break :blk null;
                },
                1 => 0,
                else => unreachable,
            };
        }
        if (direction) |d| anim.direction = @intCast(d);

        anim.previous_velocity = v;
        const store = anim.frames[direction orelse anim.direction].get(state);
        return switch (store) {
            .single => store.single,
            .slice => store.slice[anim.current_frame],
        };
    }
};

const FsAccessError = error{
    OutOfMemory,
    FailedToOpenDirectory,
    FailedToCreateDirectory,
    AppDataDirUnavailable,
    AntivirusInterference,

    InvalidFilepath,
};

const DataDir = union(enum) {
    InPackage,
    Standard,
    Custom: []const u8,
};

pub const TextureStore = union(enum) { single: SDL.Texture, slice: []SDL.Texture };

pub const AnimationData = struct {
    const Self = @This();

    idle: TextureStore,
    jumping: TextureStore,
    shooting: TextureStore,
    walking: TextureStore,

    // This should be in comptime but the fetching of room data prohibits that currently
    pub fn init(name: []const u8, textures: TextureMap) Self {
        std.debug.assert(name.len <= 10);
        // This wierdness is to avoid an allocator when getting the textures,
        var name_buf: [19]u8 = undefined;
        std.mem.copyForwards(u8, &name_buf, name);
        const name_buf_end = name_buf[name.len..];

        return Self{
            .idle = blk: {
                std.mem.copyForwards(u8, name_buf_end, "_idle");
                break :blk (textures.get(name_buf[0 .. name.len + 5]) orelse textures.get("fallback").?);
            },
            .jumping = blk: {
                std.mem.copyForwards(u8, name_buf_end, "_jumping");
                break :blk (textures.get(name_buf[0 .. name.len + 8]) orelse textures.get("fallback").?);
            },
            .shooting = blk: {
                std.mem.copyForwards(u8, name_buf_end, "_shooting");
                break :blk (textures.get(name_buf[0 .. name.len + 9]) orelse textures.get("fallback").?);
            },
            .walking = blk: {
                std.mem.copyForwards(u8, name_buf_end, "_walking");
                break :blk (textures.get(name_buf[0 .. name.len + 8]) orelse textures.get("fallback").?);
            },
        };
    }

    pub fn get(self: *Self, state: World.State) TextureStore {
        return switch (state) {
            .idle => self.idle,
            .jumping => self.jumping,
            .shooting => self.shooting,
            .walking => self.walking,
        };
    }
};

// ----
// Textures should be named like following:
// name_directionid_state_n
// ----

pub fn loadTextures(r: *SDL.Renderer, allocator: std.mem.Allocator) !std.StringArrayHashMap(TextureStore) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = arena.allocator();

    const location = DataDir.InPackage;

    var dir = try getOrMakeDataDir(arena_allocator, location);
    var walker = try dir.walk(arena_allocator);
    defer {
        walker.deinit();
        dir.close();
        arena.deinit();
    }

    var result = std.StringArrayHashMap(TextureStore).init(allocator);
    // Add these here to act as missing textures
    var fb_surface = try SDL.createRgbSurfaceWithFormat(1, 1, .rgb555);
    try fb_surface.fillRect(null, SDL.Color.magenta);

    try result.put("fallback", TextureStore{ .single = try SDL.createTextureFromSurface(r.*, fb_surface) });

    var path_arraylist = std.ArrayList([]const u8).init(arena_allocator);
    while (try walker.next()) |f| {
        if (f.kind == .file and std.mem.eql(u8, ".png", std.fs.path.extension(f.path))) {
            const buf = try arena_allocator.alloc(u8, f.path.len);
            // Copy into permanent buffer, we clear later just like everything else in this block
            std.mem.copyForwards(u8, buf, f.path);
            try path_arraylist.append(buf);
        }
    }

    // Sort array so we can easily append the items after one another later
    std.mem.sort([]const u8, path_arraylist.items, {}, comparePaths);

    {
        var buffer: [100]SDL.Texture = undefined;
        // Keep track of where in the buffer we currently are
        var buffer_pointer: usize = 0;
        // The name of the file without the path extension and numbering
        // For comparing against
        var prev_filename_stem: []const u8 = "null";

        std.log.info("Found the following images: \n {s}", .{path_arraylist.items});
        for (path_arraylist.items) |f| {
            const path = switch (location) {
                .InPackage => fs.path.joinZ(arena_allocator, &[_][]const u8{ "assets", f }) catch continue,
                .Standard => fs.path.joinZ(allocator, &[_][]const u8{ fs.getAppDataDir(allocator, "Crimsonlink") catch continue, f }) catch continue,
                .Custom => continue,
            };
            const file_basename = getFilepathStem(f) catch continue;
            const file_basename_permanent = allocator.alloc(u8, file_basename.len) catch continue;
            std.mem.copyForwards(u8, file_basename_permanent, file_basename);

            const texture = try SDL.image.loadTexture(r.*, path);

            if (std.mem.eql(u8, file_basename, prev_filename_stem)) {
                buffer_pointer += 1;
                buffer[buffer_pointer] = texture;
            } else {
                // Here we need to add something to the hash map, as something is loaded
                // Start by adding what was previously in the buffer to the list
                if (buffer_pointer == 0) {
                    try result.put(prev_filename_stem, TextureStore{ .single = buffer[0] });
                } else {
                    const group_texture = try allocator.alloc(SDL.Texture, buffer_pointer + 1);
                    std.mem.copyBackwards(SDL.Texture, group_texture, buffer[0 .. buffer_pointer + 1]);
                    try result.put(prev_filename_stem, TextureStore{ .slice = group_texture });
                }
                buffer_pointer = 0;

                // Then add the current iteration into the buffer
                buffer[buffer_pointer] = texture;
            }
            prev_filename_stem = file_basename_permanent;
        }
    }
    return result;
}

fn comparePaths(_: void, lhs: []const u8, rhs: []const u8) bool {
    const a = fs.path.stem(lhs);
    const b = fs.path.stem(rhs);
    return std.mem.order(u8, a, b).compare(.lt);
}

pub fn getTexture(textures: TextureMap, name: []const u8) TextureStore {
    return textures.get(name) orelse textures.get("fallback").?;
}

fn getFilepathStem(path: []const u8) FsAccessError![]const u8 {
    var filename = fs.path.stem(path);
    while (filename[filename.len - 1] >= '0' and filename[filename.len - 1] <= '9')
        filename = filename[0 .. filename.len - 1];

    // Remove the last _ that separates the numbering
    return if (filename[filename.len - 1] == '_') filename[0 .. filename.len - 1] else filename;
}

fn getOrMakeDataDir(allocator: std.mem.Allocator, data_dir: DataDir) FsAccessError!fs.Dir {
    switch (data_dir) {
        // In the final product we want the stuff to be in this directory, not the other 2 below
        .Standard => {
            const maybe_dir = try fs.getAppDataDir(allocator, "Crimsonlink");
            return fs.openDirAbsolute(maybe_dir, .{ .iterate = true }) catch |err| switch (err) {
                error.FileNotFound => blk: {
                    std.debug.print("Did not find data dir at '{s}', creating directory", .{maybe_dir});
                    fs.makeDirAbsolute(maybe_dir) catch return FsAccessError.FailedToCreateDirectory;
                    break :blk fs.openDirAbsolute(maybe_dir, .{ .iterate = true }) catch FsAccessError.FailedToOpenDirectory;
                },
                error.AntivirusInterference => error.AntivirusInterference,
                else => FsAccessError.FailedToOpenDirectory,
            };
        },
        .InPackage => {
            const exe_path = fs.selfExeDirPathAlloc(allocator) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.FailedToOpenDirectory,
            };
            const path = fs.path.resolve(allocator, &[_][]const u8{ exe_path, "..", "..", "..", "assets" }) catch return error.FailedToOpenDirectory;
            std.debug.print("opening path: {s} as fallback\n", .{path});
            return fs.openDirAbsolute(path, .{ .iterate = true }) catch FsAccessError.FailedToOpenDirectory;
        },
        else => return FsAccessError.FailedToOpenDirectory,
    }
}
