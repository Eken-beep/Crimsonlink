pub const packages = struct {
    pub const @"122050b7d335326149738d72f74c8d1b7bdb89c07b12c1fa9b87fe61b69ae7750a21" = struct {
        pub const build_root = "/home/edvin/.cache/zig/p/122050b7d335326149738d72f74c8d1b7bdb89c07b12c1fa9b87fe61b69ae7750a21";
        pub const build_zig = @import("122050b7d335326149738d72f74c8d1b7bdb89c07b12c1fa9b87fe61b69ae7750a21");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "raylib", "12205f45151f556dd41348acc8a93099f19d6a2e830978ace86733ce0bfe52978812" },
        };
    };
    pub const @"12205f45151f556dd41348acc8a93099f19d6a2e830978ace86733ce0bfe52978812" = struct {
        pub const build_root = "/home/edvin/.cache/zig/p/12205f45151f556dd41348acc8a93099f19d6a2e830978ace86733ce0bfe52978812";
        pub const build_zig = @import("12205f45151f556dd41348acc8a93099f19d6a2e830978ace86733ce0bfe52978812");
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "raylib-zig", "122050b7d335326149738d72f74c8d1b7bdb89c07b12c1fa9b87fe61b69ae7750a21" },
};
