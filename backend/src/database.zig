const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

// In SQLite, SQLITE_TRANSIENT is defined as a special constant (-1)
// We're using a null function pointer instead, which works the same
const SQLITE_TRANSIENT: c.sqlite3_destructor_type = null;

pub const DatabaseError = error{
    OpenFailed,
    InitFailed,
    QueryFailed,
    DataError,
};

pub const Issue = struct {
    id: usize,
    repo_name: []const u8,
    title: []const u8,
    body: []const u8,
    state: []const u8, // "open" or "closed"
    created_at: i64,
    updated_at: i64,
};

pub const PullRequest = struct {
    id: usize,
    repo_name: []const u8,
    title: []const u8,
    body: []const u8,
    source_branch: []const u8,
    target_branch: []const u8,
    state: []const u8, // "open", "closed", or "merged"
    created_at: i64,
    updated_at: i64,
};

var db: ?*c.sqlite3 = null;

pub fn init() !void {
    const db_path = "data/git_station.db";

    // Create data directory if it doesn't exist
    try std.fs.cwd().makePath("data");

    // Open database
    if (c.sqlite3_open(db_path, &db) != c.SQLITE_OK) {
        std.debug.print("Failed to open database\n", .{});
        return DatabaseError.OpenFailed;
    }

    // Create tables if they don't exist
    const create_issues_table =
        \\CREATE TABLE IF NOT EXISTS issues (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  repo_name TEXT NOT NULL,
        \\  title TEXT NOT NULL,
        \\  body TEXT NOT NULL,
        \\  state TEXT NOT NULL DEFAULT 'open',
        \\  created_at INTEGER NOT NULL,
        \\  updated_at INTEGER NOT NULL
        \\);
    ;

    const create_pull_requests_table =
        \\CREATE TABLE IF NOT EXISTS pull_requests (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  repo_name TEXT NOT NULL,
        \\  title TEXT NOT NULL,
        \\  body TEXT NOT NULL,
        \\  source_branch TEXT NOT NULL,
        \\  target_branch TEXT NOT NULL,
        \\  state TEXT NOT NULL DEFAULT 'open',
        \\  created_at INTEGER NOT NULL,
        \\  updated_at INTEGER NOT NULL
        \\);
    ;

    if (execSQL(create_issues_table) != c.SQLITE_OK or execSQL(create_pull_requests_table) != c.SQLITE_OK) {
        std.debug.print("Failed to create tables\n", .{});
        return DatabaseError.InitFailed;
    }
}

pub fn deinit() void {
    if (db != null) {
        _ = c.sqlite3_close(db);
        db = null;
    }
}

pub fn execSQL(sql: [*:0]const u8) c_int {
    var errmsg: [*c]u8 = null;
    const result = c.sqlite3_exec(db, sql, null, null, &errmsg);
    if (errmsg != null) {
        c.sqlite3_free(errmsg);
    }
    return result;
}

// Issue functions
pub fn createIssue(repo_name: []const u8, title: []const u8, body: []const u8, allocator: std.mem.Allocator) !usize {
    const c_repo_name = try allocator.dupeZ(u8, repo_name);
    defer allocator.free(c_repo_name);
    const c_title = try allocator.dupeZ(u8, title);
    defer allocator.free(c_title);
    const c_body = try allocator.dupeZ(u8, body);
    defer allocator.free(c_body);

    const timestamp = std.time.timestamp();

    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "INSERT INTO issues (repo_name, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?)";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_text(stmt, 1, c_repo_name, -1, SQLITE_TRANSIENT);
    const title_len2: c_int = @intCast(c_title.len);
    _ = c.sqlite3_bind_text(stmt, 2, c_title, title_len2, SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_text(stmt, 3, c_body, -1, SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_int64(stmt, 4, timestamp);
    _ = c.sqlite3_bind_int64(stmt, 5, timestamp);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return DatabaseError.QueryFailed;
    }

    const last_id = c.sqlite3_last_insert_rowid(db);
    return @intCast(last_id);
}

pub fn getIssue(id: usize, allocator: std.mem.Allocator) !Issue {
    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "SELECT id, repo_name, title, body, state, created_at, updated_at FROM issues WHERE id = ?";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    const id_i64: i64 = @intCast(id);
    _ = c.sqlite3_bind_int64(stmt, 1, id_i64);

    if (c.sqlite3_step(stmt) != c.SQLITE_ROW) {
        return DatabaseError.DataError;
    }

    const issue_id_i64 = c.sqlite3_column_int64(stmt, 0);
    const issue_id: usize = @intCast(issue_id_i64);
    const repo_name = c.sqlite3_column_text(stmt, 1);
    const title = c.sqlite3_column_text(stmt, 2);
    const body = c.sqlite3_column_text(stmt, 3);
    const state = c.sqlite3_column_text(stmt, 4);
    const created_at = c.sqlite3_column_int64(stmt, 5);
    const updated_at = c.sqlite3_column_int64(stmt, 6);

    if (repo_name == null or title == null or body == null or state == null) {
        return DatabaseError.DataError;
    }

    return Issue{
        .id = issue_id,
        .repo_name = try allocator.dupe(u8, std.mem.span(repo_name)),
        .title = try allocator.dupe(u8, std.mem.span(title)),
        .body = try allocator.dupe(u8, std.mem.span(body)),
        .state = try allocator.dupe(u8, std.mem.span(state)),
        .created_at = created_at,
        .updated_at = updated_at,
    };
}

pub fn listIssues(repo_name: []const u8, allocator: std.mem.Allocator) ![]Issue {
    var issues = std.ArrayList(Issue).init(allocator);
    defer issues.deinit();

    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "SELECT id, repo_name, title, body, state, created_at, updated_at FROM issues WHERE repo_name = ? ORDER BY id DESC";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    const c_repo_name = try allocator.dupeZ(u8, repo_name);
    defer allocator.free(c_repo_name);
    _ = c.sqlite3_bind_text(stmt, 1, c_repo_name, -1, SQLITE_TRANSIENT);

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const issue_id_i64 = c.sqlite3_column_int64(stmt, 0);
        const issue_id: usize = @intCast(issue_id_i64);
        const repo = c.sqlite3_column_text(stmt, 1);
        const title = c.sqlite3_column_text(stmt, 2);
        const body = c.sqlite3_column_text(stmt, 3);
        const state = c.sqlite3_column_text(stmt, 4);
        const created_at = c.sqlite3_column_int64(stmt, 5);
        const updated_at = c.sqlite3_column_int64(stmt, 6);

        if (repo == null or title == null or body == null or state == null) {
            continue;
        }

        try issues.append(Issue{
            .id = issue_id,
            .repo_name = try allocator.dupe(u8, std.mem.span(repo)),
            .title = try allocator.dupe(u8, std.mem.span(title)),
            .body = try allocator.dupe(u8, std.mem.span(body)),
            .state = try allocator.dupe(u8, std.mem.span(state)),
            .created_at = created_at,
            .updated_at = updated_at,
        });
    }

    return issues.toOwnedSlice();
}

pub fn updateIssue(id: usize, title: ?[]const u8, body: ?[]const u8, state: ?[]const u8, allocator: std.mem.Allocator) !void {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    var params = std.ArrayList([]const u8).init(allocator);
    defer {
        for (params.items) |param| {
            allocator.free(param);
        }
        params.deinit();
    }

    if (title != null) {
        try parts.append("title = ?");
        try params.append(try allocator.dupeZ(u8, title.?));
    }

    if (body != null) {
        try parts.append("body = ?");
        try params.append(try allocator.dupeZ(u8, body.?));
    }

    if (state != null) {
        try parts.append("state = ?");
        try params.append(try allocator.dupeZ(u8, state.?));
    }

    if (parts.items.len == 0) {
        return; // Nothing to update
    }

    try parts.append("updated_at = ?");
    const timestamp = std.time.timestamp();

    var sql_buf = std.ArrayList(u8).init(allocator);
    defer sql_buf.deinit();

    try sql_buf.writer().print("UPDATE issues SET ", .{});
    for (parts.items, 0..) |part, i| {
        try sql_buf.writer().print("{s}", .{part});
        if (i < parts.items.len - 1) {
            try sql_buf.writer().print(", ", .{});
        }
    }
    try sql_buf.writer().print(" WHERE id = ?", .{});

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, sql_buf.items.ptr, @intCast(sql_buf.items.len), &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var param_idx: usize = 1;
    for (params.items) |param| {
        const idx: c_int = @intCast(param_idx);
        _ = c.sqlite3_bind_text(stmt, idx, param.ptr, -1, SQLITE_TRANSIENT);
        param_idx += 1;
    }

    const timestamp_idx: c_int = @intCast(param_idx);
    _ = c.sqlite3_bind_int64(stmt, timestamp_idx, timestamp);
    param_idx += 1;

    const id_idx: c_int = @intCast(param_idx);
    const id_i64: i64 = @intCast(id);
    _ = c.sqlite3_bind_int64(stmt, id_idx, id_i64);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return DatabaseError.QueryFailed;
    }
}

// Pull Request functions
pub fn createPullRequest(repo_name: []const u8, title: []const u8, body: []const u8, source_branch: []const u8, target_branch: []const u8, allocator: std.mem.Allocator) !usize {
    const c_repo_name = try allocator.dupeZ(u8, repo_name);
    defer allocator.free(c_repo_name);
    const c_title = try allocator.dupeZ(u8, title);
    defer allocator.free(c_title);
    const c_body = try allocator.dupeZ(u8, body);
    defer allocator.free(c_body);
    const c_source_branch = try allocator.dupeZ(u8, source_branch);
    defer allocator.free(c_source_branch);
    const c_target_branch = try allocator.dupeZ(u8, target_branch);
    defer allocator.free(c_target_branch);

    const timestamp = std.time.timestamp();

    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "INSERT INTO pull_requests (repo_name, title, body, source_branch, target_branch, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_text(stmt, 1, c_repo_name, -1, SQLITE_TRANSIENT);
    const title_len2: c_int = @intCast(c_title.len);
    _ = c.sqlite3_bind_text(stmt, 2, c_title, title_len2, SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_text(stmt, 3, c_body, -1, SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_text(stmt, 4, c_source_branch, -1, SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_text(stmt, 5, c_target_branch, -1, SQLITE_TRANSIENT);
    _ = c.sqlite3_bind_int64(stmt, 6, timestamp);
    _ = c.sqlite3_bind_int64(stmt, 7, timestamp);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return DatabaseError.QueryFailed;
    }

    const last_id = c.sqlite3_last_insert_rowid(db);
    return @intCast(last_id);
}

pub fn getPullRequest(id: usize, allocator: std.mem.Allocator) !PullRequest {
    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "SELECT id, repo_name, title, body, source_branch, target_branch, state, created_at, updated_at FROM pull_requests WHERE id = ?";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    const id_i64: i64 = @intCast(id);
    _ = c.sqlite3_bind_int64(stmt, 1, id_i64);

    if (c.sqlite3_step(stmt) != c.SQLITE_ROW) {
        return DatabaseError.DataError;
    }

    const pr_id_i64 = c.sqlite3_column_int64(stmt, 0);
    const pr_id: usize = @intCast(pr_id_i64);
    const repo_name = c.sqlite3_column_text(stmt, 1);
    const title = c.sqlite3_column_text(stmt, 2);
    const body = c.sqlite3_column_text(stmt, 3);
    const source_branch = c.sqlite3_column_text(stmt, 4);
    const target_branch = c.sqlite3_column_text(stmt, 5);
    const state = c.sqlite3_column_text(stmt, 6);
    const created_at = c.sqlite3_column_int64(stmt, 7);
    const updated_at = c.sqlite3_column_int64(stmt, 8);

    if (repo_name == null or title == null or body == null or source_branch == null or target_branch == null or state == null) {
        return DatabaseError.DataError;
    }

    return PullRequest{
        .id = pr_id,
        .repo_name = try allocator.dupe(u8, std.mem.span(repo_name)),
        .title = try allocator.dupe(u8, std.mem.span(title)),
        .body = try allocator.dupe(u8, std.mem.span(body)),
        .source_branch = try allocator.dupe(u8, std.mem.span(source_branch)),
        .target_branch = try allocator.dupe(u8, std.mem.span(target_branch)),
        .state = try allocator.dupe(u8, std.mem.span(state)),
        .created_at = created_at,
        .updated_at = updated_at,
    };
}

pub fn listPullRequests(repo_name: []const u8, allocator: std.mem.Allocator) ![]PullRequest {
    var pull_requests = std.ArrayList(PullRequest).init(allocator);

    var stmt: ?*c.sqlite3_stmt = null;
    const sql = "SELECT id, repo_name, title, body, source_branch, target_branch, state, created_at, updated_at FROM pull_requests WHERE repo_name = ? ORDER BY id DESC";
    if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    const c_repo_name = try allocator.dupeZ(u8, repo_name);
    defer allocator.free(c_repo_name);
    _ = c.sqlite3_bind_text(stmt, 1, c_repo_name, -1, SQLITE_TRANSIENT);

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const pr_id_i64 = c.sqlite3_column_int64(stmt, 0);
        const pr_id: usize = @intCast(pr_id_i64);
        const repo = c.sqlite3_column_text(stmt, 1);
        const title = c.sqlite3_column_text(stmt, 2);
        const body = c.sqlite3_column_text(stmt, 3);
        const source_branch = c.sqlite3_column_text(stmt, 4);
        const target_branch = c.sqlite3_column_text(stmt, 5);
        const state = c.sqlite3_column_text(stmt, 6);
        const created_at = c.sqlite3_column_int64(stmt, 7);
        const updated_at = c.sqlite3_column_int64(stmt, 8);

        if (repo == null or title == null or body == null or source_branch == null or target_branch == null or state == null) {
            continue;
        }

        try pull_requests.append(PullRequest{
            .id = pr_id,
            .repo_name = try allocator.dupe(u8, std.mem.span(repo)),
            .title = try allocator.dupe(u8, std.mem.span(title)),
            .body = try allocator.dupe(u8, std.mem.span(body)),
            .source_branch = try allocator.dupe(u8, std.mem.span(source_branch)),
            .target_branch = try allocator.dupe(u8, std.mem.span(target_branch)),
            .state = try allocator.dupe(u8, std.mem.span(state)),
            .created_at = created_at,
            .updated_at = updated_at,
        });
    }

    return pull_requests.toOwnedSlice();
}

pub fn updatePullRequest(id: usize, title: ?[]const u8, body: ?[]const u8, state: ?[]const u8, allocator: std.mem.Allocator) !void {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();

    var params = std.ArrayList([]const u8).init(allocator);
    defer {
        for (params.items) |param| {
            allocator.free(param);
        }
        params.deinit();
    }

    if (title != null) {
        try parts.append("title = ?");
        try params.append(try allocator.dupeZ(u8, title.?));
    }

    if (body != null) {
        try parts.append("body = ?");
        try params.append(try allocator.dupeZ(u8, body.?));
    }

    if (state != null) {
        try parts.append("state = ?");
        try params.append(try allocator.dupeZ(u8, state.?));
    }

    if (parts.items.len == 0) {
        return; // Nothing to update
    }

    try parts.append("updated_at = ?");
    const timestamp = std.time.timestamp();

    var sql_buf = std.ArrayList(u8).init(allocator);
    defer sql_buf.deinit();

    try sql_buf.writer().print("UPDATE pull_requests SET ", .{});
    for (parts.items, 0..) |part, i| {
        try sql_buf.writer().print("{s}", .{part});
        if (i < parts.items.len - 1) {
            try sql_buf.writer().print(", ", .{});
        }
    }
    try sql_buf.writer().print(" WHERE id = ?", .{});

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, sql_buf.items.ptr, @intCast(sql_buf.items.len), &stmt, null) != c.SQLITE_OK) {
        return DatabaseError.QueryFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    var param_idx: usize = 1;
    for (params.items) |param| {
        const idx: c_int = @intCast(param_idx);
        _ = c.sqlite3_bind_text(stmt, idx, param.ptr, -1, SQLITE_TRANSIENT);
        param_idx += 1;
    }

    const timestamp_idx: c_int = @intCast(param_idx);
    _ = c.sqlite3_bind_int64(stmt, timestamp_idx, timestamp);
    param_idx += 1;

    const id_idx: c_int = @intCast(param_idx);
    const id_i64: i64 = @intCast(id);
    _ = c.sqlite3_bind_int64(stmt, id_idx, id_i64);

    if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
        return DatabaseError.QueryFailed;
    }
}

pub fn mergePullRequest(id: usize, allocator: std.mem.Allocator) !void {
    // First get the PR details to get repo, source and target branches
    const pull_request = try getPullRequest(id, allocator);
    defer {
        allocator.free(pull_request.repo_name);
        allocator.free(pull_request.title);
        allocator.free(pull_request.body);
        allocator.free(pull_request.source_branch);
        allocator.free(pull_request.target_branch);
        allocator.free(pull_request.state);
    }

    // Update PR status to merged
    try updatePullRequest(id, null, null, "merged", allocator);
}

pub fn deleteBranchFromPullRequest(pr_id: usize, allocator: std.mem.Allocator) ![]const u8 {
    // First get the PR details to get repo and source branch
    const pull_request = try getPullRequest(pr_id, allocator);
    defer {
        allocator.free(pull_request.repo_name);
        allocator.free(pull_request.title);
        allocator.free(pull_request.body);
        allocator.free(pull_request.source_branch);
        allocator.free(pull_request.target_branch);
        allocator.free(pull_request.state);
    }

    // Return the source branch name (the branch to delete)
    return try allocator.dupe(u8, pull_request.source_branch);
}

pub fn closePullRequest(id: usize, allocator: std.mem.Allocator) !void {
    // Simply update the PR status to closed
    try updatePullRequest(id, null, null, "closed", allocator);
}
