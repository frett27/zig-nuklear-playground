const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Builder = std.build.Builder;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const Target = std.Target;

pub fn build(b: *Builder) void {

    const exe = b.addExecutable("first-gui", "first-gui.zig");


    const target = b.standardTargetOptions(.{});

    exe.setTarget(target);

    exe.setBuildMode(b.standardReleaseOptions());

    exe.addPackage(.{
        .name = "zig-nuklear",
        .path = "zig-nuklear/nuklear.zig",
    });
    
    exe.addIncludeDir("zig-nuklear/src/c");

    exe.addObjectFile("zig-nuklear/zig-out/lib/libzig-nuklear.a");


    // SDL Software backend dependencies

    exe.addIncludeDir("/usr/include");
    exe.addIncludeDir("/usr/include/SDL2");

    // debian / ubuntu specific for SDL
    exe.addIncludeDir("/usr/include/x86_64-linux-gnu");

    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");
    exe.linkSystemLibrary("SDL2_image");

    // SDL gfx related elements
    exe.addIncludeDir("backends");
    exe.addObjectFile("backends/sdl2_gfx/.libs/libSDL2_gfx.a");

    exe.setOutputDir("bin");

    // stripping symbols reduce the size of the exe
    // exe.strip = true;
    exe.linkLibC();

    b.default_step.dependOn(&exe.step);
}
