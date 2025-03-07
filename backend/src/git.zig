const std = @import("std");
const c = @cImport({
    @cDefine("_FILE_OFFSET_BITS", "64");
    @cInclude("git2.h");
});

pub const GitError = error{ GitInitFailed, GitOpenFailed };

pub fn init() void {
    _ = c.git_libgit2_init();
}

pub fn deinit() void {
    _ = c.git_libgit2_shutdown();
}

pub fn createRepository(path: []const u8, allocator: std.mem.Allocator) !void {
    var repo: ?*c.git_repository = null;
    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    if (c.git_repository_init(&repo, c_path, 0) < 0) {
        std.debug.print("Failed to create repo\n", .{});
        return GitError.GitInitFailed;
    }
    c.git_repository_free(repo);
}

pub fn openRepository(path: []const u8, allocator: std.mem.Allocator) !*c.git_repository {
    var repo: ?*c.git_repository = null;
    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    if (c.git_repository_open(&repo, c_path) < 0) {
        std.debug.print("Failed to open repo\n", .{});
        return GitError.GitOpenFailed;
    }
    return repo.?;
}

pub fn freeRepository(repo: *c.git_repository) void {
    c.git_repository_free(repo);
}

pub fn listRepositories(dir_path: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var repos = std.ArrayList([]const u8).init(allocator);
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const full_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.name });

        if (isBareRepository(full_path) or isNonBareRepository(full_path)) {
            try repos.append(try allocator.dupe(u8, entry.name));
        }
    }
    return repos.toOwnedSlice();
}

fn isBareRepository(path: []const u8) bool {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const head = std.fmt.bufPrint(&buf, "{s}/HEAD", .{path}) catch return false;
    const config = std.fmt.bufPrint(&buf, "{s}/config", .{path}) catch return false;

    const head_exists = std.fs.accessAbsolute(head, .{}) catch return false;
    const config_exists = std.fs.accessAbsolute(config, .{}) catch return false;
    return head_exists == void{} and config_exists == void{};
}

fn isNonBareRepository(path: []const u8) bool {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const git_dir = std.fmt.bufPrint(&buf, "{s}/.git", .{path}) catch return false;

    const git_dir_exists = std.fs.accessAbsolute(git_dir, .{}) catch return false;
    return git_dir_exists == void{};
}
