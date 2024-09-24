const std = @import("std");
const SDL = @import("sdl2");

pub fn getTransparentAreas(allocator: std.mem.Allocator, surface: SDL.Surface) error{OutOfMemory}![]SDL.Rectangle {
    const w: u32 = @intCast(surface.ptr.*.w);
    const h: u32 = @intCast(surface.ptr.*.h);

    const pixels = @as([*]u32, @ptrCast(@alignCast(surface.ptr.*.pixels)));

    var searching = false;

    // Probably never more than 10 inner walls in one room
    var rects: [10]SDL.Rectangle = undefined;
    var nr_rects: u32 = 0;

    loop: for (0..w * h) |i| {
        const color = surface.getRGBA(pixels[i]);
        if (!searching and color.a == 0) {
            searching = true;
            // This one can't be outside the image
            const coordinates = pxIdToCoordinats(i, w, h).?;
            if (coordinates[0] > w or coordinates[0] < 0 or coordinates[1] > h or coordinates[1] < 0) continue;
            if (isInsidePrevious(rects[0..nr_rects], coordinates[0], coordinates[1])) {
                searching = false;
                continue;
            }
            rects[nr_rects].x = @intCast(coordinates[0]);
            rects[nr_rects].y = @intCast(coordinates[1]);
        } else if (searching and color.a != 0) {
            // Because we are now at the first pixel after the blank space, we move back one
            var current_pixel: u32 = @intCast(i - 1);

            // Then we go down until we find the first pixel that is not transparent
            // If the pixel is outside the image => we just stop anyways because we know we're outside the supposed hitbox
            while (surface.getRGBA(current_pixel).a == 0) : (current_pixel += w) {
                const c: @Vector(2, c_int) = @intCast(pxIdToCoordinats(current_pixel, w, h) orelse break);
                if (c[0] > w or c[0] < 0 or c[1] > h or c[1] < 0) continue :loop;
                rects[nr_rects].width = c[0] - rects[nr_rects].x;
                rects[nr_rects].height = c[1] - rects[nr_rects].y;
            }

            std.debug.print("Adding wall {any} {d}\n", .{ rects[nr_rects], nr_rects });
            nr_rects += 1;
            searching = false;
        }
    }

    const result = try allocator.alloc(SDL.Rectangle, nr_rects);
    std.mem.copyForwards(SDL.Rectangle, result, rects[0..nr_rects]);
    return result;
}

fn pxIdToCoordinats(id: usize, w: u32, h: u32) ?@Vector(2, u32) {
    const id_u32: u32 = @intCast(id);
    if (id > w * h) return null;
    return @Vector(2, u32){
        id_u32 % (w - 1),
        @divTrunc(id_u32, w) + 1,
    };
}

fn isInsidePrevious(rects: []SDL.Rectangle, x: u32, y: u32) bool {
    for (rects) |r|
        if (x >= r.x and y >= r.y and x <= r.x + r.width and y <= r.y + r.height) return true;

    return false;
}
