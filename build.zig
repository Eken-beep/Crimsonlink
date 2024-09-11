const std = @import("std");
const Sdk = @import("SDL/Sdk.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Crimsonlink",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const sdk = Sdk.init(b, null, null);
    sdk.link(exe, .dynamic, .SDL2);
    sdk.link(exe, .dynamic, .SDL2_ttf);
    exe.root_module.addImport("sdl2", sdk.getWrapperModule());

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.addPathDir("SDL/bin");
    const run_step = b.step("run", "Run Crimsonlink");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&unit_tests.step);

    b.installArtifact(exe);
}
