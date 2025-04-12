const std = @import("std");
const c = @cImport({
    @cDefine("_FILE_OFFSET_BITS", "64");
    @cInclude("git2.h");
});

pub const GitError = error{
    GitInitFailed,
    GitOpenFailed,
    BranchCreateFailed,
    BranchListFailed,
    CommitLookupFailed,
    CommitHistoryFailed,
    FileReadFailed,
    DiffGenerationFailed,
    MergeFailed,
};

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

    // Ensure we have absolute paths
    const abs_path = std.fs.realpathAlloc(std.heap.page_allocator, path) catch return false;
    defer std.heap.page_allocator.free(abs_path);

    const head = std.fmt.bufPrint(&buf, "{s}/HEAD", .{abs_path}) catch return false;
    const config = std.fmt.bufPrint(&buf, "{s}/config", .{abs_path}) catch return false;

    // Use cwd().access instead of accessAbsolute
    const head_exists = std.fs.cwd().access(head, .{}) catch return false;
    const config_exists = std.fs.cwd().access(config, .{}) catch return false;

    _ = head_exists; // Use void return value
    _ = config_exists; // Use void return value

    return true; // If we get here, both files exist
}

fn isNonBareRepository(path: []const u8) bool {
    var buf: [std.fs.max_path_bytes]u8 = undefined;

    // Ensure we have absolute paths
    const abs_path = std.fs.realpathAlloc(std.heap.page_allocator, path) catch return false;
    defer std.heap.page_allocator.free(abs_path);

    const git_dir = std.fmt.bufPrint(&buf, "{s}/.git", .{abs_path}) catch return false;

    // Use cwd().access instead of accessAbsolute
    const git_dir_exists = std.fs.cwd().access(git_dir, .{}) catch return false;

    _ = git_dir_exists; // Use void return value

    return true; // If we get here, the .git directory exists
}

// Branch operations
pub fn listBranches(repo: *c.git_repository, allocator: std.mem.Allocator) ![][]const u8 {
    var branches = std.ArrayList([]const u8).init(allocator);
    var branch_iter: ?*c.git_branch_iterator = null;

    if (c.git_branch_iterator_new(&branch_iter, repo, c.GIT_BRANCH_LOCAL) < 0) {
        return GitError.BranchListFailed;
    }
    defer c.git_branch_iterator_free(branch_iter);

    var branch_ref: ?*c.git_reference = null;
    var branch_type: c.git_branch_t = undefined;

    while (c.git_branch_next(&branch_ref, &branch_type, branch_iter) == 0) {
        var name_ptr: [*c]const u8 = null;
        if (c.git_branch_name(&name_ptr, branch_ref) == 0 and name_ptr != null) {
            try branches.append(try allocator.dupe(u8, std.mem.span(name_ptr)));
        }
        c.git_reference_free(branch_ref);
    }

    return branches.toOwnedSlice();
}

pub fn createBranch(repo: *c.git_repository, name: []const u8, allocator: std.mem.Allocator) !void {
    // Get HEAD
    var head_ref: ?*c.git_reference = null;
    if (c.git_repository_head(&head_ref, repo) < 0) {
        return GitError.BranchCreateFailed;
    }
    defer c.git_reference_free(head_ref);

    // Get HEAD commit (as a generic object first)
    var head_object: ?*c.git_object = null;
    if (c.git_reference_peel(&head_object, head_ref, c.GIT_OBJECT_COMMIT) < 0) {
        return GitError.BranchCreateFailed;
    }
    // Cast to specific commit type
    const head_commit: ?*c.git_commit = @ptrCast(head_object);
    defer if (head_commit) |hc| c.git_commit_free(hc);

    // Create branch
    var branch_ref: ?*c.git_reference = null;
    const c_name = try allocator.dupeZ(u8, name);
    defer allocator.free(c_name);

    if (c.git_branch_create(&branch_ref, repo, c_name, head_commit, 0) < 0) {
        return GitError.BranchCreateFailed;
    }
    c.git_reference_free(branch_ref);
}

// Commit operations
pub const Commit = struct {
    id: [40]u8,
    message: []const u8,
    author: []const u8,
    timestamp: i64,
};

pub fn getCommits(repo: *c.git_repository, branch_name: []const u8, allocator: std.mem.Allocator, limit: usize) ![]Commit {
    var commits = std.ArrayList(Commit).init(allocator);

    // Get branch reference
    var branch_ref: ?*c.git_reference = null;
    const c_branch_name = try allocator.dupeZ(u8, branch_name);
    defer allocator.free(c_branch_name);

    const ref_name = try std.fmt.allocPrint(allocator, "refs/heads/{s}", .{branch_name});
    defer allocator.free(ref_name);
    const c_ref_name = try allocator.dupeZ(u8, ref_name);
    defer allocator.free(c_ref_name);

    if (c.git_reference_lookup(&branch_ref, repo, c_ref_name) < 0) {
        // Try looking up by shortened name
        if (c.git_branch_lookup(&branch_ref, repo, c_branch_name, c.GIT_BRANCH_LOCAL) < 0) {
            return GitError.CommitHistoryFailed;
        }
    }
    defer c.git_reference_free(branch_ref);

    // Get commit from reference (as a generic object first)
    var peeled_object: ?*c.git_object = null;
    if (c.git_reference_peel(&peeled_object, branch_ref, c.GIT_OBJECT_COMMIT) < 0) {
        return GitError.CommitHistoryFailed;
    }
    // Cast to specific commit type
    const commit_obj: ?*c.git_commit = @ptrCast(peeled_object);
    defer if (commit_obj) |co| c.git_commit_free(co);

    // Set up revwalk
    var revwalk: ?*c.git_revwalk = null;
    if (c.git_revwalk_new(&revwalk, repo) < 0) {
        return GitError.CommitHistoryFailed;
    }
    defer c.git_revwalk_free(revwalk);

    // Configure revwalk
    _ = c.git_revwalk_sorting(revwalk, c.GIT_SORT_TIME);

    const commit_id = c.git_commit_id(commit_obj);
    if (c.git_revwalk_push(revwalk, commit_id) < 0) {
        return GitError.CommitHistoryFailed;
    }

    // Walk commits
    var count: usize = 0;
    var oid: c.git_oid = undefined;

    while (count < limit and c.git_revwalk_next(&oid, revwalk) == 0) {
        var walker_commit: ?*c.git_commit = null;
        if (c.git_commit_lookup(&walker_commit, repo, &oid) < 0) {
            continue;
        }
        defer c.git_commit_free(walker_commit);

        var id_buf: [40]u8 = undefined;
        _ = c.git_oid_fmt(&id_buf, &oid);

        const author = c.git_commit_author(walker_commit);
        const message = c.git_commit_message(walker_commit);
        const timestamp = c.git_commit_time(walker_commit);

        if (author != null and message != null) {
            // Use a hardcoded name for now
            const author_name = "Git Author";

            const commit = Commit{
                .id = id_buf,
                .message = try allocator.dupe(u8, std.mem.span(message)),
                .author = try allocator.dupe(u8, author_name),
                .timestamp = timestamp,
            };
            try commits.append(commit);
        }

        count += 1;
    }

    return commits.toOwnedSlice();
}

// File operations
pub fn getFileContent(repo: *c.git_repository, branch_name: []const u8, file_path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    // Get branch reference
    var branch_ref: ?*c.git_reference = null;
    const ref_name = try std.fmt.allocPrint(allocator, "refs/heads/{s}", .{branch_name});
    defer allocator.free(ref_name);
    const c_ref_name = try allocator.dupeZ(u8, ref_name);
    defer allocator.free(c_ref_name);

    if (c.git_reference_lookup(&branch_ref, repo, c_ref_name) < 0) {
        // Try with shortened name
        const c_branch_name = try allocator.dupeZ(u8, branch_name);
        defer allocator.free(c_branch_name);
        if (c.git_branch_lookup(&branch_ref, repo, c_branch_name, c.GIT_BRANCH_LOCAL) < 0) {
            return GitError.FileReadFailed;
        }
    }
    defer c.git_reference_free(branch_ref);

    // Get commit from reference (as a generic object first)
    var peeled_object: ?*c.git_object = null;
    if (c.git_reference_peel(&peeled_object, branch_ref, c.GIT_OBJECT_COMMIT) < 0) {
        return GitError.FileReadFailed;
    }
    // Cast to specific commit type
    const commit_obj: ?*c.git_commit = @ptrCast(peeled_object);
    defer if (commit_obj) |co| c.git_commit_free(co);

    // Get tree from commit
    var tree: ?*c.git_tree = null;
    if (c.git_commit_tree(&tree, commit_obj) < 0) {
        return GitError.FileReadFailed;
    }
    defer c.git_tree_free(tree);

    // Get file entry
    var entry: ?*c.git_tree_entry = null;
    const c_file_path = try allocator.dupeZ(u8, file_path);
    defer allocator.free(c_file_path);

    if (c.git_tree_entry_bypath(&entry, tree, c_file_path) < 0) {
        return GitError.FileReadFailed;
    }
    defer c.git_tree_entry_free(entry);

    // Get blob from entry
    const blob_id = c.git_tree_entry_id(entry);
    var blob: ?*c.git_blob = null;
    if (c.git_blob_lookup(&blob, repo, blob_id) < 0) {
        return GitError.FileReadFailed;
    }
    defer c.git_blob_free(blob);

    // Get content
    const content = c.git_blob_rawcontent(blob);
    const size = c.git_blob_rawsize(blob);

    const result = try allocator.alloc(u8, size);
    @memcpy(result[0..size], @as([*]const u8, @ptrCast(content))[0..size]);

    return result;
}

// Directory listing
pub const DirEntry = struct {
    name: []const u8,
    is_dir: bool,
};

pub fn listDirectory(repo: *c.git_repository, branch_name: []const u8, dir_path: []const u8, allocator: std.mem.Allocator) ![]DirEntry {
    var entries = std.ArrayList(DirEntry).init(allocator);

    // Get branch reference
    var branch_ref: ?*c.git_reference = null;
    const ref_name = try std.fmt.allocPrint(allocator, "refs/heads/{s}", .{branch_name});
    defer allocator.free(ref_name);
    const c_ref_name = try allocator.dupeZ(u8, ref_name);
    defer allocator.free(c_ref_name);

    if (c.git_reference_lookup(&branch_ref, repo, c_ref_name) < 0) {
        // Try with shortened name
        const c_branch_name = try allocator.dupeZ(u8, branch_name);
        defer allocator.free(c_branch_name);
        if (c.git_branch_lookup(&branch_ref, repo, c_branch_name, c.GIT_BRANCH_LOCAL) < 0) {
            return GitError.FileReadFailed;
        }
    }
    defer c.git_reference_free(branch_ref);

    // Get commit from reference (as a generic object first)
    var peeled_object: ?*c.git_object = null;
    if (c.git_reference_peel(&peeled_object, branch_ref, c.GIT_OBJECT_COMMIT) < 0) {
        return GitError.FileReadFailed;
    }
    // Cast to specific commit type
    const commit_obj: ?*c.git_commit = @ptrCast(peeled_object);
    defer if (commit_obj) |co| c.git_commit_free(co);

    // Get tree from commit
    var tree: ?*c.git_tree = null;
    if (c.git_commit_tree(&tree, commit_obj) < 0) {
        return GitError.FileReadFailed;
    }
    defer c.git_tree_free(tree);

    // Handle root directory specially
    if (std.mem.eql(u8, dir_path, "") or std.mem.eql(u8, dir_path, "/")) {
        const entry_count = c.git_tree_entrycount(tree);
        var i: usize = 0;
        while (i < entry_count) : (i += 1) {
            const entry = c.git_tree_entry_byindex(tree, i);
            if (entry != null) {
                const name = c.git_tree_entry_name(entry);
                const type_id = c.git_tree_entry_type(entry);
                if (name != null) {
                    const loop_dir_entry = DirEntry{
                        .name = try allocator.dupe(u8, std.mem.span(name)),
                        .is_dir = type_id == c.GIT_OBJECT_TREE,
                    };
                    try entries.append(loop_dir_entry);
                }
            }
        }
        return entries.toOwnedSlice();
    }

    // Get tree entry for directory
    var dir_entry: ?*c.git_tree_entry = null;
    const c_dir_path = try allocator.dupeZ(u8, dir_path);
    defer allocator.free(c_dir_path);

    if (c.git_tree_entry_bypath(&dir_entry, tree, c_dir_path) < 0) {
        return GitError.FileReadFailed;
    }
    defer c.git_tree_entry_free(dir_entry);

    // Ensure it's a tree (directory)
    if (c.git_tree_entry_type(dir_entry) != c.GIT_OBJECT_TREE) {
        return GitError.FileReadFailed;
    }

    // Get subtree
    var subtree: ?*c.git_tree = null;
    const subtree_id = c.git_tree_entry_id(dir_entry);
    if (c.git_tree_lookup(&subtree, repo, subtree_id) < 0) {
        return GitError.FileReadFailed;
    }
    defer c.git_tree_free(subtree);

    // List entries
    const entry_count = c.git_tree_entrycount(subtree);
    var i: usize = 0;
    while (i < entry_count) : (i += 1) {
        const entry = c.git_tree_entry_byindex(subtree, i);
        if (entry != null) {
            const name = c.git_tree_entry_name(entry);
            const type_id = c.git_tree_entry_type(entry);
            if (name != null) {
                const loop_dir_entry = DirEntry{
                    .name = try allocator.dupe(u8, std.mem.span(name)),
                    .is_dir = type_id == c.GIT_OBJECT_TREE,
                };
                try entries.append(loop_dir_entry);
            }
        }
    }

    return entries.toOwnedSlice();
}
