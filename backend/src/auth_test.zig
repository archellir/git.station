const std = @import("std");
const testing = std.testing;
const auth = @import("auth.zig");
const config = @import("config.zig");

// Reset the auth system before each test
fn setupTest() void {
    auth.deinit();
    auth.init();
}

test "authenticate with valid credentials" {
    setupTest();
    const result = try auth.authenticate(config.Config.ADMIN_USERNAME, config.Config.ADMIN_PASSWORD);
    try testing.expect(result == .ok);
}

test "authenticate with invalid username" {
    try testing.expect(!auth.authenticate("wrong_user", auth.ADMIN_PASSWORD));
}

test "authenticate with invalid password" {
    try testing.expect(!auth.authenticate(auth.ADMIN_USERNAME, "wrong_password"));
}

test "session management - create and validate" {
    setupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a session
    const token = try auth.createSession(allocator);

    // Validate the token exists
    try testing.expect(auth.validateSession(token));
}

test "session management - create and remove" {
    setupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a session
    const token = try auth.createSession(allocator);

    // Remove the session
    auth.removeSession(token);

    // Verify the token is no longer valid
    try testing.expect(!auth.validateSession(token));
}

test "session management - create different tokens" {
    setupTest();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create two sessions
    const token1 = try auth.createSession(allocator);
    const token2 = try auth.createSession(allocator);

    // Both should be valid
    try testing.expect(auth.validateSession(token1));
    try testing.expect(auth.validateSession(token2));

    // Tokens should be different
    try testing.expect(!std.mem.eql(u8, token1, token2));
}
