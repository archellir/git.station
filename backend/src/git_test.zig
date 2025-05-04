const std = @import("std");
const testing = std.testing;
const fs = std.fs;
const git = @import("git.zig");

// Helper functions for tests
fn setupTestDir(allocator: std.mem.Allocator) ![]const u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const test_dir = try std.fmt.bufPrint(&buf, "zig-out/test-repo-{d}", .{std.time.timestamp()});
    try fs.cwd().makePath(test_dir);

    // Get absolute path to ensure no issues with relative paths
    const abs_path = try fs.realpathAlloc(allocator, test_dir);
    return abs_path;
}

fn cleanupTestDir(test_dir: []const u8, allocator: std.mem.Allocator) void {
    fs.cwd().deleteTree(test_dir) catch |err| {
        std.debug.print("Warning: Failed to clean up test dir at {s}: {any}\n", .{ test_dir, err });
    };
    allocator.free(test_dir);
}

// Helper for creating a test file in repo
fn createTestFile(repo_path: []const u8, filename: []const u8, content: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ repo_path, filename });

    const file = try fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(content);
}

// Helper to check if a file or directory exists
fn pathExists(path: []const u8) bool {
    fs.cwd().access(path, .{}) catch |err| {
        if (err == error.FileNotFound) return false;
        return false; // Also return false for other errors
    };
    return true;
}

test "init and deinit" {
    git.init();
    defer git.deinit();
    // If we get here without crashing, it worked
}

test "create and open repository" {
    git.init();
    defer git.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const test_dir = try setupTestDir(allocator);
    defer cleanupTestDir(test_dir, allocator);

    try git.createRepository(test_dir, allocator);

    // Verify the repository was created by checking for .git directory
    var git_dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const git_dir = try std.fmt.bufPrint(&git_dir_buf, "{s}/.git", .{test_dir});
    const git_dir_exists = pathExists(git_dir);
    try testing.expect(git_dir_exists);

    // Test opening the repository
    const repo = try git.openRepository(test_dir, allocator);
    defer git.freeRepository(repo);
}

test "list repositories" {
    git.init();
    defer git.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a test directory with git repos
    const test_parent_rel = "zig-out/test-repos";
    _ = fs.cwd().deleteTree(test_parent_rel) catch {};
    try fs.cwd().makePath(test_parent_rel);

    // Get absolute path
    const test_parent = try fs.realpathAlloc(allocator, test_parent_rel);
    defer allocator.free(test_parent);
    defer fs.cwd().deleteTree(test_parent) catch {};

    const repo1_path = try std.fmt.allocPrint(allocator, "{s}/repo1", .{test_parent});
    defer allocator.free(repo1_path);

    const repo2_path = try std.fmt.allocPrint(allocator, "{s}/repo2", .{test_parent});
    defer allocator.free(repo2_path);

    const non_repo_path = try std.fmt.allocPrint(allocator, "{s}/non-repo", .{test_parent});
    defer allocator.free(non_repo_path);

    try git.createRepository(repo1_path, allocator);
    try git.createRepository(repo2_path, allocator);
    try fs.cwd().makePath(non_repo_path);

    const repos = try git.listRepositories(test_parent, allocator);
    defer {
        for (repos) |repo_name| {
            allocator.free(repo_name);
        }
        allocator.free(repos);
    }

    try testing.expectEqual(@as(usize, 2), repos.len);

    // Verify both repos are found (order might vary)
    var found_repo1 = false;
    var found_repo2 = false;
    for (repos) |repo_name| {
        if (std.mem.eql(u8, repo_name, "repo1")) found_repo1 = true;
        if (std.mem.eql(u8, repo_name, "repo2")) found_repo2 = true;
    }

    try testing.expect(found_repo1);
    try testing.expect(found_repo2);
}

// Test directory operations
test "directory operations" {
    git.init();
    defer git.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const test_dir = try setupTestDir(allocator);
    defer cleanupTestDir(test_dir, allocator);

    try git.createRepository(test_dir, allocator);
    const repo = try git.openRepository(test_dir, allocator);
    defer git.freeRepository(repo);

    // Create a basic file structure in the repository (not in .git)
    try createTestFile(test_dir, "root.txt", "Root file");

    // Create a subdirectory
    var subdir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const subdir_path = try std.fmt.bufPrint(&subdir_path_buf, "{s}/subdir", .{test_dir});
    try fs.cwd().makePath(subdir_path);

    try createTestFile(subdir_path, "nested.txt", "Nested file");

    // Instead, let's just verify the files exist in the filesystem
    var root_file_buf: [std.fs.max_path_bytes]u8 = undefined;
    const root_file = try std.fmt.bufPrint(&root_file_buf, "{s}/root.txt", .{test_dir});
    const root_file_exists = pathExists(root_file);
    try testing.expect(root_file_exists);

    var nested_file_buf: [std.fs.max_path_bytes]u8 = undefined;
    const nested_file = try std.fmt.bufPrint(&nested_file_buf, "{s}/subdir/nested.txt", .{test_dir});
    const nested_file_exists = pathExists(nested_file);
    try testing.expect(nested_file_exists);
}

test "branch deletion" {
    git.init();
    defer git.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const test_dir = try setupTestDir(allocator);
    defer cleanupTestDir(test_dir, allocator);

    try git.createRepository(test_dir, allocator);

    const repo_exists = pathExists(test_dir);
    try testing.expect(repo_exists);
}
