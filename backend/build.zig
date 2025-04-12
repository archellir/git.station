const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "git-station",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link libraries for the main application
    exe.linkSystemLibrary("sqlite3");
    exe.linkSystemLibrary("git2");
    exe.linkLibC();

    b.installArtifact(exe);

    // Auth tests
    const auth_tests = b.addTest(.{
        .root_source_file = b.path("src/auth_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    auth_tests.linkLibC();

    // Create a run step for the auth tests
    const run_auth_tests = b.addRunArtifact(auth_tests);

    const test_auth_step = b.step("test-auth", "Run the authentication tests");
    test_auth_step.dependOn(&run_auth_tests.step);

    // Add unit tests step with SQLite
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link SQLite for the tests
    unit_tests.linkSystemLibrary("sqlite3");
    unit_tests.linkLibC();

    // Add specific test for database_test.zig
    const db_tests = b.addTest(.{
        .root_source_file = b.path("src/database_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link SQLite for the database tests
    db_tests.linkSystemLibrary("sqlite3");
    db_tests.linkLibC();

    // Add git tests with specific configurations
    const git_tests = b.addTest(.{
        .root_source_file = b.path("src/git_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Configure git tests with libgit2
    git_tests.linkSystemLibrary("git2");

    // Instead of using the build system for these paths, we'll rely on the direct test commands below
    git_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_db_tests = b.addRunArtifact(db_tests);
    const run_git_tests = b.addRunArtifact(git_tests);

    // This creates a "test" step that VS Code will use
    const test_unit_step = b.step("test", "Run unit tests");
    test_unit_step.dependOn(&run_unit_tests.step);
    test_unit_step.dependOn(&run_db_tests.step);

    // Add a separate step for git tests
    const test_git_step = b.step("test-git", "Run git tests");
    test_git_step.dependOn(&run_git_tests.step);

    // Create a comprehensive test-all step
    const test_all_step = b.step("test-all", "Run all tests (unit, db, auth, git)");
    test_all_step.dependOn(&run_unit_tests.step);
    test_all_step.dependOn(&run_db_tests.step);
    test_all_step.dependOn(&run_auth_tests.step);
    test_all_step.dependOn(&run_git_tests.step);

    // Add specific test for main_test.zig
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link libraries for the main tests
    main_tests.linkSystemLibrary("sqlite3");
    main_tests.linkSystemLibrary("git2");
    main_tests.linkLibC();

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_main_step = b.step("test-main", "Run the main.zig tests");
    test_main_step.dependOn(&run_main_tests.step);

    // Also add main tests to test-all step
    test_all_step.dependOn(&run_main_tests.step);

    // Add platform-specific direct test commands
    if (builtin.os.tag == .macos) {
        // macOS direct command for Git tests
        const direct_git_test_mac = b.addSystemCommand(&[_][]const u8{ "zig", "test", "src/git_test.zig", "-lc", "-lgit2", "-I/opt/homebrew/include", "-L/opt/homebrew/lib" });

        const direct_git_test_mac_step = b.step("test-git-mac", "Run git tests directly with macOS paths");
        direct_git_test_mac_step.dependOn(&direct_git_test_mac.step);
    }

    // Linux direct command for Git tests (for Docker)
    const direct_git_test_linux = b.addSystemCommand(&[_][]const u8{ "zig", "test", "src/git_test.zig", "-lc", "-lgit2", "-I/usr/include", "-L/usr/lib/x86_64-linux-gnu" });

    const direct_git_test_linux_step = b.step("test-git-linux", "Run git tests directly with Linux paths (for Docker)");
    direct_git_test_linux_step.dependOn(&direct_git_test_linux.step);

    // Direct command to run all tests on Linux/Docker
    const direct_all_tests_linux = b.addSystemCommand(&[_][]const u8{ "sh", "-c", "zig test src/main.zig -lc -lsqlite3 && " ++
        "zig test src/database_test.zig -lc -lsqlite3 && " ++
        "zig test src/auth_test.zig -lc && " ++
        "zig test src/git_test.zig -lc -lgit2 -I/usr/include -L/usr/lib/x86_64-linux-gnu" });

    const direct_all_tests_linux_step = b.step("test-all-linux", "Run all tests directly with Linux paths (for Docker)");
    direct_all_tests_linux_step.dependOn(&direct_all_tests_linux.step);

    // Direct command to run all tests on macOS
    const direct_all_tests_mac = b.addSystemCommand(&[_][]const u8{ "sh", "-c", "zig test src/main.zig -lc -lsqlite3 && " ++
        "zig test src/database_test.zig -lc -lsqlite3 && " ++
        "zig test src/auth_test.zig -lc && " ++
        "zig test src/git_test.zig -lc -lgit2 -I/opt/homebrew/include -L/opt/homebrew/lib" });

    const direct_all_tests_mac_step = b.step("test-all-mac", "Run all tests directly with macOS paths");
    direct_all_tests_mac_step.dependOn(&direct_all_tests_mac.step);

    // Direct command to run main tests on macOS
    const direct_main_test_mac = b.addSystemCommand(&[_][]const u8{ "zig", "test", "src/main_test.zig", "-lc", "-lsqlite3", "-lgit2", "-I/opt/homebrew/include", "-L/opt/homebrew/lib" });

    const direct_main_test_mac_step = b.step("test-main-mac", "Run main tests directly with macOS paths");
    direct_main_test_mac_step.dependOn(&direct_main_test_mac.step);

    // Run command for the main executable
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
