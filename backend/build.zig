const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the main module
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "git.station",
        .root_module = exe_mod,
    });

    // Link system libraries
    exe.linkSystemLibrary("git2");
    exe.linkLibC();

    const include_paths = comptime [_][]const u8{
        "/opt/homebrew/include", // Homebrew
        "/usr/local/include", // Standard
    };
    const library_paths = comptime [_][]const u8{
        "/opt/homebrew/lib", // Homebrew
        "/usr/local/lib", // Standard
    };

    inline for (include_paths) |path| {
        exe.addIncludePath(.{ .cwd_relative = path });
    }
    inline for (library_paths) |path| {
        exe.addLibraryPath(.{ .cwd_relative = path });
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Create unit tests
    const unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    unit_tests.linkSystemLibrary("git2");
    unit_tests.linkLibC();
    inline for (include_paths) |path| {
        unit_tests.addIncludePath(.{ .cwd_relative = path });
    }
    inline for (library_paths) |path| {
        unit_tests.addLibraryPath(.{ .cwd_relative = path });
    }

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
