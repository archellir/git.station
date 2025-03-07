const std = @import("std");
const c = @cImport({
    @cInclude("git2.h");
});

pub const GitError = error{
    GitInitFailed,
    GitOpenFailed,
    GitCloneFailed,
    GitBranchFailed,
};

pub fn init() void {
    _ = c.git_libgit2_init();
}

pub fn deinit() void {
    _ = c.git_libgit2_shutdown();
}

// Create a new repository
pub fn createRepository(path: []const u8, allocator: std.mem.Allocator) !void {
    var repo: ?*c.git_repository = null;

    // Convert Zig string to C string
    const c_path = try std.cstr.addNullByte(allocator, path);
    defer allocator.free(c_path);

    const result = c.git_repository_init(&repo, c_path, 0);
    if (result < 0) {
        std.debug.print("Failed to create repository: {s}\n", .{c.git_error_last().?.message});
        return GitError.GitInitFailed;
    }

    defer c.git_repository_free(repo);
    std.debug.print("Repository created at: {s}\n", .{path});
}

// Open an existing repository
pub fn openRepository(path: []const u8, allocator: std.mem.Allocator) !*c.git_repository {
    var repo: ?*c.git_repository = null;

    // Convert Zig string to C string
    const c_path = try std.cstr.addNullByte(allocator, path);
    defer allocator.free(c_path);

    const result = c.git_repository_open(&repo, c_path);
    if (result < 0) {
        std.debug.print("Failed to open repository: {s}\n", .{c.git_error_last().?.message});
        return GitError.GitOpenFailed;
    }

    return repo.?;
}

// List all repositories in a directory
pub fn listRepositories(dir_path: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });
    defer dir.close();

    var repos = std.ArrayList([]const u8).init(allocator);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .Directory) {
            // Check if this directory is a git repository
            var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const full_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}/.git", .{ dir_path, entry.name });

            if (std.fs.accessAbsolute(full_path, .{})) {
                const repo_name = try allocator.dupe(u8, entry.name);
                try repos.append(repo_name);
            } else |_| {
                // Not a git repository, check if bare repository
                var git_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
                const git_path = try std.fmt.bufPrint(&git_path_buf, "{s}/{s}", .{ dir_path, entry.name });

                if (isBareRepository(git_path)) {
                    const repo_name = try allocator.dupe(u8, entry.name);
                    try repos.append(repo_name);
                }
            }
        }
    }

    return repos.toOwnedSlice();
}

// Check if a directory is a bare git repository
fn isBareRepository(path: []const u8) bool {
    // Simple check for bare repositories - look for common files
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    const head_path = std.fmt.bufPrintZ(&buf, "{s}/HEAD", .{path}) catch return false;
    const config_path = std.fmt.bufPrintZ(&buf, "{s}/config", .{path}) catch return false;

    const head_exists = std.fs.accessAbsolute(head_path, .{}) catch return false;
    const config_exists = std.fs.accessAbsolute(config_path, .{}) catch return false;

    return head_exists and config_exists;
}
