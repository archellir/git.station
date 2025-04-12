const std = @import("std");

pub const ADMIN_USERNAME = "admin";
pub const ADMIN_PASSWORD = "password123";

// Simple session token map (in-memory sessions)
var sessions = std.StringHashMap(bool).init(std.heap.page_allocator);

pub fn init() void {
    sessions = std.StringHashMap(bool).init(std.heap.page_allocator);
}

pub fn deinit() void {
    var it = sessions.iterator();
    while (it.next()) |entry| {
        std.heap.page_allocator.free(entry.key_ptr.*);
    }
    sessions.deinit();
}

pub fn authenticate(username: []const u8, password: []const u8) bool {
    return std.mem.eql(u8, username, ADMIN_USERNAME) and std.mem.eql(u8, password, ADMIN_PASSWORD);
}

pub fn createSession(allocator: std.mem.Allocator) ![]const u8 {
    var token_buf: [64]u8 = undefined;

    // Generate random session token
    std.crypto.random.bytes(&token_buf);

    // Format the token as a hex string
    const token = try std.fmt.allocPrint(allocator, "{s}", .{std.fmt.fmtSliceHexLower(&token_buf)});

    // Make a heap-allocated copy of the token for the session map
    const token_copy = try std.heap.page_allocator.dupe(u8, token);

    // Store token in sessions map
    try sessions.put(token_copy, true);

    return token;
}

pub fn validateSession(token: []const u8) bool {
    var it = sessions.iterator();
    while (it.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, token)) {
            return true;
        }
    }
    return false;
}

pub fn removeSession(token: []const u8) void {
    var key_to_remove: ?[]const u8 = null;

    // Find the matching key
    var it = sessions.iterator();
    while (it.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, token)) {
            key_to_remove = entry.key_ptr.*;
            break;
        }
    }

    // Remove the session if found
    if (key_to_remove != null) {
        _ = sessions.remove(key_to_remove.?);
        std.heap.page_allocator.free(key_to_remove.?);
    }
}
