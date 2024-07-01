const std = @import("std");
const rl = @import("raylib");
const fs = std.fs;

const DRAW_HITBOXES = true;

pub const TextureMap = std.StringArrayHashMap(TextureStore);

pub const Animation = struct {
    const Anim = @This();

    nr_frames: u8,
    current_frame: u8 = 0,

    frametime: f32,
    timer: f32 = 0,
    frames: [][]rl.Texture2D,
    direction: u8 = 0,
    avalilable_directions: u8 = 1,

    pub fn step(anim: *Anim, dt: f32, moving: bool) void {
        if (!moving) anim.current_frame = 0 else {
            anim.timer += dt;
            if (anim.timer > anim.frametime) {
                anim.timer = 0;
                anim.current_frame += 1;
                if (anim.current_frame == anim.nr_frames) anim.current_frame = 0;
            }
        }
    }

    pub fn getFrame(anim: *const Anim, pos: @Vector(2, f32), v: @Vector(2, f32)) rl.Texture2D {
        const angle: f32 = std.math.atan2(v[1], v[0]);
        var direction: ?usize = null;

        if (v[0] != 0 or v[1] != 0) {
            // Calculate the value here and approximate it to one of the 8 possible directions
            const pi = std.math.pi;
            direction = switch (anim.avalilable_directions) {
                8 => blk: {
                    const directions = [_]f32{
                        -pi / 2.0,
                        -pi / 4.0,
                        0,
                        pi / 4.0,
                        pi / 2.0,
                        3 * pi / 4.0,
                        pi,
                        -3 * pi / 4.0,
                    };
                    var closest: f32 = directions[0];
                    for (directions) |d| {
                        if (@abs(d - angle) < @abs(closest - angle)) closest = d;
                    }
                    for (directions, 0..) |d, i| {
                        if (d == closest) break :blk i;
                    } else break :blk 10;
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
                    for (directions, 0..) |d, i| {
                        if (d == closest) break :blk i;
                    } else break :blk 10;
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
                    for (directions, 0..) |d, i| {
                        if (d == closest) break :blk i;
                    } else break :blk 10;
                },
                1 => 0,
                else => unreachable,
            };
        }

        if (DRAW_HITBOXES) {
            const px: i32 = @intFromFloat(pos[0]);
            const py: i32 = @intFromFloat(pos[1]);
            const x: i32 = @intFromFloat(@cos(angle) * 100);
            const y: i32 = @intFromFloat(@sin(angle) * 100);
            rl.drawLine(px, py, x + px, y + py, rl.Color.sky_blue);
        }

        return anim.frames[direction orelse 0][anim.current_frame];
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

pub const TextureStore = union { single: rl.Texture2D, slice: []rl.Texture2D };

pub fn loadTextures(allocator: std.mem.Allocator) !std.StringArrayHashMap(TextureStore) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = arena.allocator();

    var dir = try getOrMakeDataDir(arena_allocator, DataDir.InPackage);
    var walker = try dir.walk(arena_allocator);
    defer {
        walker.deinit();
        dir.close();
        arena.deinit();
    }

    var result = std.StringArrayHashMap(TextureStore).init(allocator);
    // Add these here to act as missing textures
    try result.put("fallback_single", TextureStore{ .single = rl.loadTextureFromImage(rl.genImageColor(50, 50, rl.Color.pink)) });
    const fallback_many = try allocator.alloc(rl.Texture2D, 12);
    for (0..fallback_many.len) |i| fallback_many[i] = rl.loadTextureFromImage(rl.genImageColor(50, 50, rl.Color.pink));
    try result.put("fallback_many", TextureStore{ .slice = fallback_many });

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
        var buffer: [100]rl.Texture2D = undefined;
        // Keep track of where in the buffer we currently are
        var buffer_pointer: usize = 0;
        // The name of the file without the path extension and numbering
        // For comparing against
        var prev_filename_stem: []const u8 = "null";

        for (path_arraylist.items) |f| {
            const path = fs.path.joinZ(arena_allocator, &[_][]const u8{ "assets", f }) catch continue;
            const file_basename = getFilepathStem(f) catch continue;
            const file_basename_permanent = try allocator.alloc(u8, file_basename.len);
            std.mem.copyForwards(u8, file_basename_permanent, file_basename);
            std.debug.print("{s}\n", .{file_basename});

            const image = rl.loadImage(path);

            if (std.mem.eql(u8, file_basename, prev_filename_stem)) {
                buffer_pointer += 1;
                buffer[buffer_pointer] = rl.loadTextureFromImage(image);
            } else {
                // Here we need to add something to the hash map, as something is loaded
                // Start by adding what was previously in the buffer to the list
                if (buffer_pointer == 0) {
                    try result.put(prev_filename_stem, TextureStore{ .single = buffer[0] });
                } else {
                    const group_texture = try allocator.alloc(rl.Texture2D, buffer_pointer + 1);
                    std.mem.copyBackwards(rl.Texture2D, group_texture, buffer[0 .. buffer_pointer + 1]);
                    try result.put(prev_filename_stem, TextureStore{ .slice = group_texture });
                }
                buffer_pointer = 0;

                // Then add the current iteration into the buffer
                buffer[buffer_pointer] = rl.loadTextureFromImage(image);
            }
            prev_filename_stem = file_basename_permanent;
        }
    }
    std.debug.print("LOADED IMAGES:\n", .{});
    for (result.keys()) |k| std.debug.print("{s}\n", .{k});
    return result;
}

fn comparePaths(_: void, lhs: []const u8, rhs: []const u8) bool {
    const a = fs.path.stem(lhs);
    const b = fs.path.stem(rhs);
    return std.mem.order(u8, a, b).compare(.lt);
}

pub fn getTexture(textures: TextureMap, name: []const u8) TextureStore {
    return textures.get(name) orelse textures.get("fallback_single").?;
}

pub fn getTextures(textures: TextureMap, name: []const u8) TextureStore {
    return textures.get(name) orelse textures.get("fallback_many").?;
}

fn getFilepathStem(path: []const u8) FsAccessError![]const u8 {
    var filename = fs.path.stem(path);
    while (filename[filename.len - 1] > '0' and filename[filename.len - 1] < '9')
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
