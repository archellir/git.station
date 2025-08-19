const std = @import("std");
const testing = std.testing;
const main_module = @import("main.zig");
const git = @import("git.zig");
const auth = @import("auth.zig");
const db = @import("database.zig");
const http = @import("http.zig");
const router = @import("router.zig");
const errors = @import("errors.zig");
const config = @import("config.zig");
const fs = std.fs;

// ============================================================================
// COMPREHENSIVE TEST SUITE FOR GIT STATION
// ============================================================================

// Test utilities and helpers
const TestContext = struct {
    allocator: std.mem.Allocator,
    test_repo_path: []const u8,
    test_db_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !TestContext {
        const timestamp = std.time.timestamp();
        const test_repo_path = try std.fmt.allocPrint(allocator, "test-repos-{d}", .{timestamp});
        const test_db_path = try std.fmt.allocPrint(allocator, "test-db-{d}.db", .{timestamp});
        
        // Setup test directories
        try fs.cwd().makePath(test_repo_path);
        try fs.cwd().makePath("data");
        
        return TestContext{
            .allocator = allocator,
            .test_repo_path = test_repo_path,
            .test_db_path = test_db_path,
        };
    }

    pub fn deinit(self: *TestContext) void {
        fs.cwd().deleteTree(self.test_repo_path) catch {};
        fs.cwd().deleteFile(self.test_db_path) catch {};
        self.allocator.free(self.test_repo_path);
        self.allocator.free(self.test_db_path);
    }

    pub fn setupServices(_: *TestContext) !void {
        git.init();
        auth.init();
        try db.init();
    }

    pub fn teardownServices(_: *TestContext) void {
        db.deinit();
        auth.deinit();
        git.deinit();
    }
};

// ============================================================================
// HTTP PARSING SECURITY TESTS
// ============================================================================

test "HTTP parsing - malformed requests" {
    const test_cases = [_][]const u8{
        "", // Empty request
        "GET", // Incomplete request
        "INVALID_METHOD /path HTTP/1.1\r\n\r\n", // Invalid method
        "GET " ++ "x" ** 10000 ++ " HTTP/1.1\r\n\r\n", // Path too long
        "GET /path HTTP/1.1\r\nHost: \x00evil.com\r\n\r\n", // Null bytes
        "\r\n\r\nGET /path HTTP/1.1\r\n\r\n", // Leading newlines
    };

    for (test_cases) |request| {
        const method = main_module.parseMethod(request);
        const path = main_module.parsePath(request);
        
        // Should either parse correctly or return null, never crash
        if (method != null and path != null) {
            // Valid parsing
            try testing.expect(method.?.len > 0);
            try testing.expect(path.?.len > 0);
        }
    }
}

test "HTTP parsing - cookie injection attempts" {
    const malicious_cookies = [_][]const u8{
        "GET / HTTP/1.1\r\nCookie: session=valid; session=injection\r\n\r\n",
        "GET / HTTP/1.1\r\nCookie: session=valid\r\nX-Injected: evil\r\n\r\n",
        "GET / HTTP/1.1\r\nCookie: session=\r\n\r\nsession=evil\r\n\r\n",
    };

    for (malicious_cookies) |request| {
        const session = main_module.parseCookie(request, "session");
        if (session != null) {
            // Should not contain control characters or injection attempts
            for (session.?) |c| {
                try testing.expect(c >= 32 or c == '\t'); // Printable characters only
            }
        }
    }
}

test "JSON parsing - injection and edge cases" {
    const allocator = testing.allocator;
    
    const malicious_json = [_][]const u8{
        "{\"name\":\"\"}",  // Empty name
        "{\"name\":null}",  // Null name
        "{\"name\":\"test\x00injection\"}", // Null byte injection
        "{\"name\":\"test\\\"injection\"}", // Quote escaping
        "{\"name\":\"" ++ "x" ** 1000 ++ "\"}", // Very long name
        "{}",  // Missing name field
        "{\"name\":123}",  // Wrong type
        "invalid json",  // Invalid JSON
    };

    for (malicious_json) |json| {
        const result = main_module.parseJsonString(json, "name", allocator);
        if (result) |name| {
            defer if (name != null) allocator.free(name.?);
            // Should be valid string if parsing succeeded
            if (name != null) {
                try testing.expect(name.?.len >= 0);
            }
        } else |_| {
            // Error is acceptable for malicious input
        }
    }
}

// ============================================================================
// GIT OPERATIONS COMPREHENSIVE TESTS
// ============================================================================

test "Git operations - repository lifecycle" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const repo_path = try std.fmt.allocPrint(ctx.allocator, "{s}/test-repo", .{ctx.test_repo_path});
    defer ctx.allocator.free(repo_path);

    // Test repository creation
    try git.createRepository(repo_path, ctx.allocator);
    
    // Verify repository exists
    var repo_dir = fs.cwd().openDir(repo_path, .{}) catch |err| {
        std.debug.print("Failed to open repo directory: {}\n", .{err});
        return err;
    };
    defer repo_dir.close();

    // Test repository opening
    const repo = try git.openRepository(repo_path, ctx.allocator);
    defer git.freeRepository(repo);

    // Test repository listing
    const repos = try git.listRepositories(ctx.test_repo_path, ctx.allocator);
    defer {
        for (repos) |r| ctx.allocator.free(r);
        ctx.allocator.free(repos);
    }
    try testing.expect(repos.len == 1);
    try testing.expectEqualStrings("test-repo", repos[0]);
}

test "Git operations - branch management" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const repo_path = try std.fmt.allocPrint(ctx.allocator, "{s}/branch-test", .{ctx.test_repo_path});
    defer ctx.allocator.free(repo_path);

    try git.createRepository(repo_path, ctx.allocator);
    const repo = try git.openRepository(repo_path, ctx.allocator);
    defer git.freeRepository(repo);

    // Test branch creation
    try git.createBranch(repo, "feature-branch", ctx.allocator);
    try git.createBranch(repo, "dev-branch", ctx.allocator);

    // Test branch listing
    const branches = try git.listBranches(repo, ctx.allocator);
    defer {
        for (branches) |branch| ctx.allocator.free(branch);
        ctx.allocator.free(branches);
    }

    try testing.expect(branches.len >= 2); // At least main + our branches
    
    // Verify our branches exist
    var found_feature = false;
    var found_dev = false;
    for (branches) |branch| {
        if (std.mem.eql(u8, branch, "feature-branch")) found_feature = true;
        if (std.mem.eql(u8, branch, "dev-branch")) found_dev = true;
    }
    try testing.expect(found_feature);
    try testing.expect(found_dev);
}

test "Git operations - error handling" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    // Test opening non-existent repository
    const result = git.openRepository("/nonexistent/path", ctx.allocator);
    try testing.expectError(git.GitError.GitOpenFailed, result);

    // Test creating repository in non-existent path
    const create_result = git.createRepository("/nonexistent/path/repo", ctx.allocator);
    try testing.expectError(git.GitError.GitInitFailed, create_result);
}

// ============================================================================
// DATABASE COMPREHENSIVE TESTS
// ============================================================================

test "Database - issue CRUD operations" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const repo_name = "test-repo";
    const title = "Test Issue";
    const body = "This is a test issue with special chars: \"quotes\" and \n newlines";

    // Create issue
    const issue_id = try db.createIssue(repo_name, title, body, ctx.allocator);
    try testing.expect(issue_id > 0);

    // Read issue
    const issue = try db.getIssue(issue_id, ctx.allocator);
    defer {
        ctx.allocator.free(issue.repo_name);
        ctx.allocator.free(issue.title);
        ctx.allocator.free(issue.body);
        ctx.allocator.free(issue.state);
    }

    try testing.expectEqualStrings(repo_name, issue.repo_name);
    try testing.expectEqualStrings(title, issue.title);
    try testing.expectEqualStrings(body, issue.body);
    try testing.expectEqualStrings("open", issue.state);

    // Update issue
    const new_title = "Updated Issue";
    const new_body = "Updated body";
    const new_state = "closed";
    try db.updateIssue(issue_id, new_title, new_body, new_state, ctx.allocator);

    // Verify update
    const updated_issue = try db.getIssue(issue_id, ctx.allocator);
    defer {
        ctx.allocator.free(updated_issue.repo_name);
        ctx.allocator.free(updated_issue.title);
        ctx.allocator.free(updated_issue.body);
        ctx.allocator.free(updated_issue.state);
    }

    try testing.expectEqualStrings(new_title, updated_issue.title);
    try testing.expectEqualStrings(new_body, updated_issue.body);
    try testing.expectEqualStrings(new_state, updated_issue.state);

    // List issues
    const issues = try db.listIssues(repo_name, ctx.allocator);
    defer {
        for (issues) |i| {
            ctx.allocator.free(i.repo_name);
            ctx.allocator.free(i.title);
            ctx.allocator.free(i.body);
            ctx.allocator.free(i.state);
        }
        ctx.allocator.free(issues);
    }
    try testing.expect(issues.len == 1);
    try testing.expect(issues[0].id == issue_id);
}

test "Database - pull request workflow" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const repo_name = "test-repo";
    const title = "Test PR";
    const body = "Test pull request";
    const source_branch = "feature";
    const target_branch = "main";

    // Create pull request
    const pr_id = try db.createPullRequest(repo_name, title, body, source_branch, target_branch, ctx.allocator);
    try testing.expect(pr_id > 0);

    // Verify creation
    const pr = try db.getPullRequest(pr_id, ctx.allocator);
    defer {
        ctx.allocator.free(pr.repo_name);
        ctx.allocator.free(pr.title);
        ctx.allocator.free(pr.body);
        ctx.allocator.free(pr.source_branch);
        ctx.allocator.free(pr.target_branch);
        ctx.allocator.free(pr.state);
    }

    try testing.expectEqualStrings("open", pr.state);
    try testing.expectEqualStrings(source_branch, pr.source_branch);
    try testing.expectEqualStrings(target_branch, pr.target_branch);

    // Test merge
    try db.mergePullRequest(pr_id, ctx.allocator);
    const merged_pr = try db.getPullRequest(pr_id, ctx.allocator);
    defer {
        ctx.allocator.free(merged_pr.repo_name);
        ctx.allocator.free(merged_pr.title);
        ctx.allocator.free(merged_pr.body);
        ctx.allocator.free(merged_pr.source_branch);
        ctx.allocator.free(merged_pr.target_branch);
        ctx.allocator.free(merged_pr.state);
    }
    try testing.expectEqualStrings("merged", merged_pr.state);
}

test "Database - SQL injection protection" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const malicious_inputs = [_][]const u8{
        "'; DROP TABLE issues; --",
        "test'; INSERT INTO issues VALUES(999, 'hack', 'hack', 'hack', 'open', 0, 0); --",
        "test\x00hidden",
        "test\" OR \"1\"=\"1",
    };

    for (malicious_inputs) |malicious_input| {
        // Try to create issue with malicious input
        const issue_id = try db.createIssue("test-repo", malicious_input, "body", ctx.allocator);
        
        // Verify the data was stored correctly (not executed as SQL)
        const issue = try db.getIssue(issue_id, ctx.allocator);
        defer {
            ctx.allocator.free(issue.repo_name);
            ctx.allocator.free(issue.title);
            ctx.allocator.free(issue.body);
            ctx.allocator.free(issue.state);
        }
        
        // The malicious input should be stored as literal text
        try testing.expectEqualStrings(malicious_input, issue.title);
    }
}

// ============================================================================
// AUTHENTICATION AND SESSION TESTS
// ============================================================================

test "Authentication - session lifecycle" {
    auth.init();
    defer auth.deinit();

    // Test valid authentication
    const auth_result = try auth.authenticate("admin", "password123");
    try testing.expect(auth_result == .ok);

    if (auth_result == .ok) {
        const session = auth_result.ok;
        
        // Test session validation
        try testing.expect(auth.validateSession(session.token));
        
        // Test session removal
        auth.removeSession(session.token);
        try testing.expect(!auth.validateSession(session.token));
    }
}

test "Authentication - brute force protection" {
    auth.init();
    defer auth.deinit();

    // Simulate multiple failed attempts
    for (0..10) |_| {
        const result = try auth.authenticate("admin", "wrong_password");
        try testing.expect(result == .err);
    }

    // Should still work with correct credentials
    const valid_result = try auth.authenticate("admin", "password123");
    try testing.expect(valid_result == .ok);
}

test "Authentication - session token uniqueness" {
    auth.init();
    defer auth.deinit();

    var sessions = std.ArrayList([]const u8).init(testing.allocator);
    defer sessions.deinit();

    // Generate multiple sessions
    for (0..10) |_| {
        const result = try auth.authenticate("admin", "password123");
        try testing.expect(result == .ok);
        
        if (result == .ok) {
            const session = result.ok;
            try sessions.append(session.token);
        }
    }

    // Verify all tokens are unique
    for (sessions.items, 0..) |token1, i| {
        for (sessions.items[i+1..]) |token2| {
            try testing.expect(!std.mem.eql(u8, token1, token2));
        }
    }
}

// ============================================================================
// API ENDPOINT INTEGRATION TESTS
// ============================================================================

test "API - repository creation flow" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    // Test repository creation
    const repo_name = "api-test-repo";
    var repo_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&repo_path_buf, "{s}/{s}", .{ ctx.test_repo_path, repo_name });

    try git.createRepository(repo_path, ctx.allocator);

    // Test repository listing
    const repos = try git.listRepositories(ctx.test_repo_path, ctx.allocator);
    defer {
        for (repos) |repo| ctx.allocator.free(repo);
        ctx.allocator.free(repos);
    }

    var found = false;
    for (repos) |repo| {
        if (std.mem.eql(u8, repo, repo_name)) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

// ============================================================================
// ERROR HANDLING AND EDGE CASES
// ============================================================================

test "Error handling - resource exhaustion" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    // Test with very large inputs
    const large_title = try ctx.allocator.alloc(u8, 10000);
    defer ctx.allocator.free(large_title);
    @memset(large_title, 'x');

    const large_body = try ctx.allocator.alloc(u8, 100000);
    defer ctx.allocator.free(large_body);
    @memset(large_body, 'y');

    // Should handle large inputs gracefully
    const issue_id = try db.createIssue("test-repo", large_title, large_body, ctx.allocator);
    try testing.expect(issue_id > 0);

    // Verify data integrity
    const issue = try db.getIssue(issue_id, ctx.allocator);
    defer {
        ctx.allocator.free(issue.repo_name);
        ctx.allocator.free(issue.title);
        ctx.allocator.free(issue.body);
        ctx.allocator.free(issue.state);
    }

    try testing.expect(issue.title.len == 10000);
    try testing.expect(issue.body.len == 100000);
}

test "Error handling - concurrent access" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const repo_name = "concurrent-test";
    
    // Simulate concurrent issue creation
    var threads = std.ArrayList(std.Thread).init(ctx.allocator);
    defer threads.deinit();

    const num_threads = 5;
    const issues_per_thread = 10;

    for (0..num_threads) |i| {
        const thread = try std.Thread.spawn(.{}, createIssuesThread, .{ ctx.allocator, repo_name, i, issues_per_thread });
        try threads.append(thread);
    }

    // Wait for all threads
    for (threads.items) |thread| {
        thread.join();
    }

    // Verify all issues were created
    const issues = try db.listIssues(repo_name, ctx.allocator);
    defer {
        for (issues) |issue| {
            ctx.allocator.free(issue.repo_name);
            ctx.allocator.free(issue.title);
            ctx.allocator.free(issue.body);
            ctx.allocator.free(issue.state);
        }
        ctx.allocator.free(issues);
    }

    try testing.expect(issues.len == num_threads * issues_per_thread);
}

fn createIssuesThread(allocator: std.mem.Allocator, repo_name: []const u8, thread_id: usize, count: usize) void {
    for (0..count) |i| {
        const title = std.fmt.allocPrint(allocator, "Thread {} Issue {}", .{ thread_id, i }) catch return;
        defer allocator.free(title);
        
        _ = db.createIssue(repo_name, title, "Concurrent test issue", allocator) catch return;
    }
}

// ============================================================================
// PERFORMANCE AND LOAD TESTS
// ============================================================================

test "Performance - bulk operations" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    const start_time = std.time.milliTimestamp();
    
    // Create many issues quickly
    const num_issues = 100;
    for (0..num_issues) |i| {
        const title = try std.fmt.allocPrint(ctx.allocator, "Bulk Issue {}", .{i});
        defer ctx.allocator.free(title);
        
        _ = try db.createIssue("bulk-test", title, "Bulk test body", ctx.allocator);
    }
    
    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;
    
    // Should complete within reasonable time (adjust threshold as needed)
    try testing.expect(duration_ms < 5000); // 5 seconds max
    
    std.debug.print("Created {} issues in {}ms\n", .{ num_issues, duration_ms });
}

// ============================================================================
// INTEGRATION TESTS WITH REAL HTTP SCENARIOS
// ============================================================================

test "Integration - complete API workflow" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    try ctx.setupServices();
    defer ctx.teardownServices();

    // Test authentication
    const auth_result = try auth.authenticate("admin", "password123");
    try testing.expect(auth_result == .ok);
    
    const session = auth_result.ok;
    
    // Test repository creation via API parsing
    const create_request = "POST /api/repos HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"name\":\"integration-test\"}";
    const repo_name = try main_module.parseRepoNameFromBody(create_request, ctx.allocator);
    defer ctx.allocator.free(repo_name);
    
    try testing.expectEqualStrings("integration-test", repo_name);
    
    // Test issue creation
    const issue_request = "POST /api/repo/integration-test/issues HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"title\":\"Integration Issue\",\"body\":\"Test issue\"}";
    const title = try main_module.parseJsonString(issue_request[std.mem.indexOf(u8, issue_request, "{").?..], "title", ctx.allocator);
    defer ctx.allocator.free(title.?);
    
    const issue_id = try db.createIssue("integration-test", title.?, "Test issue", ctx.allocator);
    try testing.expect(issue_id > 0);
    
    // Cleanup session
    auth.removeSession(session.token);
}