const std = @import("std");
const testing = std.testing;
const db = @import("database.zig");
const c = @cImport({
    @cInclude("sqlite3.h");
});

// Override database path for tests
var original_open_fn: ?fn ([*:0]const u8, **c.sqlite3) c_int = null;

fn mockSqliteOpen(path: [*:0]const u8, out_db: **c.sqlite3) c_int {
    _ = path; // ignore the original path
    return original_open_fn.?("data/test_db.db", out_db);
}

// Setup and teardown
fn setupTest() !void {
    // Create data directory if it doesn't exist
    try std.fs.cwd().makePath("data");

    // Delete test database if it exists
    std.fs.cwd().deleteFile("data/test_db.db") catch {};

    try db.init();

    // Clean up any existing data
    _ = db.execSQL("DELETE FROM issues");
    _ = db.execSQL("DELETE FROM pull_requests");
}

fn cleanupTest() void {
    db.deinit();

    // Delete test database file
    std.fs.cwd().deleteFile("data/test_db.db") catch {};
}

test "database initialization" {
    try setupTest();
    defer cleanupTest();

    // Check if database was properly initialized
    // The fact that this doesn't throw an error is a success
}

test "issue creation and retrieval" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a test issue
    const repo_name = "test-repo";
    const title = "Test Issue";
    const body = "This is a test issue body";

    const issue_id = try db.createIssue(repo_name, title, body, allocator);
    try testing.expect(issue_id > 0);

    // Retrieve the issue
    const issue = try db.getIssue(issue_id, allocator);
    defer {
        allocator.free(issue.repo_name);
        allocator.free(issue.title);
        allocator.free(issue.body);
        allocator.free(issue.state);
    }

    // Verify issue properties
    try testing.expectEqualStrings(repo_name, issue.repo_name);
    try testing.expectEqualStrings(title, issue.title);
    try testing.expectEqualStrings(body, issue.body);
    try testing.expectEqualStrings("open", issue.state); // Default state
    try testing.expect(issue.id == issue_id);
}

test "issue update" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a test issue
    const repo_name = "test-repo";
    const issue_id = try db.createIssue(repo_name, "Original Title", "Original Body", allocator);

    // Update issue
    const new_title = "Updated Title";
    const new_body = "Updated Body";
    const new_state = "closed";

    try db.updateIssue(issue_id, new_title, new_body, new_state, allocator);

    // Retrieve updated issue
    const issue = try db.getIssue(issue_id, allocator);
    defer {
        allocator.free(issue.repo_name);
        allocator.free(issue.title);
        allocator.free(issue.body);
        allocator.free(issue.state);
    }

    // Verify updated properties
    try testing.expectEqualStrings(new_title, issue.title);
    try testing.expectEqualStrings(new_body, issue.body);
    try testing.expectEqualStrings(new_state, issue.state);
}

test "list issues" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create test repo with multiple issues
    const repo_name = "list-test-repo";
    const num_issues = 3;

    for (0..num_issues) |i| {
        const title = try std.fmt.allocPrint(allocator, "Issue {d}", .{i + 1});
        const body = try std.fmt.allocPrint(allocator, "Body {d}", .{i + 1});
        _ = try db.createIssue(repo_name, title, body, allocator);
    }

    // List issues
    const issues = try db.listIssues(repo_name, allocator);
    defer {
        for (issues) |issue| {
            allocator.free(issue.repo_name);
            allocator.free(issue.title);
            allocator.free(issue.body);
            allocator.free(issue.state);
        }
        allocator.free(issues);
    }

    // Verify correct number of issues returned
    try testing.expectEqual(num_issues, issues.len);

    // Issues should be returned in descending order (newest first)
    for (issues, 0..) |issue, i| {
        try testing.expectEqualStrings(repo_name, issue.repo_name);
        const expected_idx = num_issues - i;
        const expected_title = try std.fmt.allocPrint(allocator, "Issue {d}", .{expected_idx});
        try testing.expectEqualStrings(expected_title, issue.title);
    }
}

test "pull request creation and retrieval" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a test pull request
    const repo_name = "test-repo";
    const title = "Test PR";
    const body = "This is a test pull request";
    const source_branch = "feature-branch";
    const target_branch = "main";

    const pr_id = try db.createPullRequest(repo_name, title, body, source_branch, target_branch, allocator);
    try testing.expect(pr_id > 0);

    // Retrieve the pull request
    const pr = try db.getPullRequest(pr_id, allocator);
    defer {
        allocator.free(pr.repo_name);
        allocator.free(pr.title);
        allocator.free(pr.body);
        allocator.free(pr.source_branch);
        allocator.free(pr.target_branch);
        allocator.free(pr.state);
    }

    // Verify PR properties
    try testing.expectEqualStrings(repo_name, pr.repo_name);
    try testing.expectEqualStrings(title, pr.title);
    try testing.expectEqualStrings(body, pr.body);
    try testing.expectEqualStrings(source_branch, pr.source_branch);
    try testing.expectEqualStrings(target_branch, pr.target_branch);
    try testing.expectEqualStrings("open", pr.state); // Default state
    try testing.expect(pr.id == pr_id);
}

test "pull request update" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a test PR
    const repo_name = "test-repo";
    const pr_id = try db.createPullRequest(repo_name, "Original Title", "Original Body", "feature", "main", allocator);

    // Update PR
    const new_title = "Updated PR Title";
    const new_body = "Updated PR Body";
    const new_state = "closed";

    try db.updatePullRequest(pr_id, new_title, new_body, new_state, allocator);

    // Retrieve updated PR
    const pr = try db.getPullRequest(pr_id, allocator);
    defer {
        allocator.free(pr.repo_name);
        allocator.free(pr.title);
        allocator.free(pr.body);
        allocator.free(pr.source_branch);
        allocator.free(pr.target_branch);
        allocator.free(pr.state);
    }

    // Verify updated properties
    try testing.expectEqualStrings(new_title, pr.title);
    try testing.expectEqualStrings(new_body, pr.body);
    try testing.expectEqualStrings(new_state, pr.state);
}

test "merge pull request" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a test PR
    const repo_name = "test-repo";
    const pr_id = try db.createPullRequest(repo_name, "Merge Test PR", "This PR will be merged", "feature", "main", allocator);

    // Merge the PR
    try db.mergePullRequest(pr_id, allocator);

    // Retrieve the PR and check its state
    const pr = try db.getPullRequest(pr_id, allocator);
    defer {
        allocator.free(pr.repo_name);
        allocator.free(pr.title);
        allocator.free(pr.body);
        allocator.free(pr.source_branch);
        allocator.free(pr.target_branch);
        allocator.free(pr.state);
    }

    try testing.expectEqualStrings("merged", pr.state);
}

test "list pull requests" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create test repo with multiple PRs
    const repo_name = "list-test-repo";
    const num_prs = 3;

    for (0..num_prs) |i| {
        const title = try std.fmt.allocPrint(allocator, "PR {d}", .{i + 1});
        const body = try std.fmt.allocPrint(allocator, "PR Body {d}", .{i + 1});
        const source = try std.fmt.allocPrint(allocator, "feature-{d}", .{i + 1});
        _ = try db.createPullRequest(repo_name, title, body, source, "main", allocator);
    }

    // List PRs
    const prs = try db.listPullRequests(repo_name, allocator);
    defer {
        for (prs) |pr| {
            allocator.free(pr.repo_name);
            allocator.free(pr.title);
            allocator.free(pr.body);
            allocator.free(pr.source_branch);
            allocator.free(pr.target_branch);
            allocator.free(pr.state);
        }
        allocator.free(prs);
    }

    // Verify correct number of PRs returned
    try testing.expectEqual(num_prs, prs.len);

    // PRs should be returned in descending order (newest first)
    for (prs, 0..) |pr, i| {
        try testing.expectEqualStrings(repo_name, pr.repo_name);
        const expected_idx = num_prs - i;
        const expected_title = try std.fmt.allocPrint(allocator, "PR {d}", .{expected_idx});
        try testing.expectEqualStrings(expected_title, pr.title);
    }
}

test "partial updates" {
    try setupTest();
    defer cleanupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create issue and PR
    const repo_name = "partial-update-repo";
    const issue_id = try db.createIssue(repo_name, "Issue Title", "Issue Body", allocator);
    const pr_id = try db.createPullRequest(repo_name, "PR Title", "PR Body", "feature", "main", allocator);

    // Partial updates (update only title)
    try db.updateIssue(issue_id, "Updated Issue Title", null, null, allocator);
    try db.updatePullRequest(pr_id, "Updated PR Title", null, null, allocator);

    // Retrieve and verify only title changed
    const issue = try db.getIssue(issue_id, allocator);
    defer {
        allocator.free(issue.repo_name);
        allocator.free(issue.title);
        allocator.free(issue.body);
        allocator.free(issue.state);
    }

    const pr = try db.getPullRequest(pr_id, allocator);
    defer {
        allocator.free(pr.repo_name);
        allocator.free(pr.title);
        allocator.free(pr.body);
        allocator.free(pr.source_branch);
        allocator.free(pr.target_branch);
        allocator.free(pr.state);
    }

    try testing.expectEqualStrings("Updated Issue Title", issue.title);
    try testing.expectEqualStrings("Issue Body", issue.body);
    try testing.expectEqualStrings("open", issue.state);

    try testing.expectEqualStrings("Updated PR Title", pr.title);
    try testing.expectEqualStrings("PR Body", pr.body);
    try testing.expectEqualStrings("open", pr.state);
}
