const std = @import("std");
const config = @import("config.zig");
const errors = @import("errors.zig");
const logger = @import("logger.zig");

/// Session data structure
pub const Session = struct {
    token: []const u8,
    username: []const u8,
    created_at: i64,
    expires_at: i64,
    
    pub fn isExpired(self: Session) bool {
        return std.time.timestamp() > self.expires_at;
    }
    
    pub fn isValid(self: Session) bool {
        return !self.isExpired();
    }
};

/// User structure
pub const User = struct {
    username: []const u8,
    password_hash: []const u8,
    role: UserRole,
    created_at: i64,
    last_login: ?i64,
    
    pub fn checkPassword(self: User, password: []const u8) bool {
        _ = self;
        // For now, just use simple comparison
        // TODO: Implement proper password hashing with bcrypt or argon2
        return std.mem.eql(u8, password, config.Config.ADMIN_PASSWORD);
    }
};

/// User roles
pub const UserRole = enum {
    admin,
    user,
    
    pub fn toString(self: UserRole) []const u8 {
        return switch (self) {
            .admin => "admin",
            .user => "user",
        };
    }
    
    pub fn fromString(role_str: []const u8) ?UserRole {
        if (std.mem.eql(u8, role_str, "admin")) return .admin;
        if (std.mem.eql(u8, role_str, "user")) return .user;
        return null;
    }
};

/// Authentication manager
pub const AuthManager = struct {
    sessions: std.StringHashMap(Session),
    users: std.StringHashMap(User),
    allocator: std.mem.Allocator,
    session_duration: i64 = 24 * 60 * 60, // 24 hours in seconds
    
    pub fn init(allocator: std.mem.Allocator) AuthManager {
        return AuthManager{
            .sessions = std.StringHashMap(Session).init(allocator),
            .users = std.StringHashMap(User).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *AuthManager) void {
        // Clean up sessions
        var session_iter = self.sessions.iterator();
        while (session_iter.next()) |entry| {
            // Free the key (which is the same as the token)
            self.allocator.free(entry.key_ptr.*);
            // Free the username (token is same as key, so don't double-free)
            self.allocator.free(entry.value_ptr.username);
        }
        self.sessions.deinit();
        
        // Clean up users
        var user_iter = self.users.iterator();
        while (user_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.username);
            self.allocator.free(entry.value_ptr.password_hash);
        }
        self.users.deinit();
    }
    
    pub fn initializeDefaultUser(self: *AuthManager) !void {
        const admin_user = User{
            .username = try self.allocator.dupe(u8, config.Config.ADMIN_USERNAME),
            .password_hash = try self.allocator.dupe(u8, config.Config.ADMIN_PASSWORD),
            .role = .admin,
            .created_at = std.time.timestamp(),
            .last_login = null,
        };
        
        const username_key = try self.allocator.dupe(u8, config.Config.ADMIN_USERNAME);
        try self.users.put(username_key, admin_user);
        
        logger.info("Default admin user initialized", .{});
    }
    
    pub fn authenticate(self: *AuthManager, username: []const u8, password: []const u8) !errors.Result(Session) {
        // Find user
        const user = self.users.get(username) orelse {
            logger.warn("Authentication attempt for non-existent user: {s}", .{username});
            return errors.Result(Session){ .err = errors.HttpError.init(.unauthorized, "Invalid credentials") };
        };
        
        // Check password
        if (!user.checkPassword(password)) {
            logger.warn("Invalid password for user: {s}", .{username});
            return errors.Result(Session){ .err = errors.HttpError.init(.unauthorized, "Invalid credentials") };
        }
        
        // Create session
        const session = try self.createSession(username);
        
        // Update last login
        var updated_user = user;
        updated_user.last_login = std.time.timestamp();
        try self.users.put(username, updated_user);
        
        logger.info("User authenticated successfully: {s}", .{username});
        return errors.Result(Session){ .ok = session };
    }
    
    pub fn createSession(self: *AuthManager, username: []const u8) !Session {
        // Generate random session token
        var token_buf: [config.Config.SESSION_TOKEN_LENGTH]u8 = undefined;
        std.crypto.random.bytes(&token_buf);
        
        // Format as hex string - this will be our key and session token
        const token = try std.fmt.allocPrint(self.allocator, "{s}", .{std.fmt.fmtSliceHexLower(&token_buf)});
        
        const now = std.time.timestamp();
        const session = Session{
            .token = token, // Use the same token string
            .username = try self.allocator.dupe(u8, username),
            .created_at = now,
            .expires_at = now + self.session_duration,
        };
        
        // Store session using the token as both key and value.token
        // HashMap will take ownership of the key
        try self.sessions.put(token, session);
        
        logger.debug("Session created for user: {s}", .{username});
        return session;
    }
    
    pub fn validateSession(self: *AuthManager, token: []const u8) ?Session {
        const session = self.sessions.get(token) orelse return null;
        
        if (session.isExpired()) {
            // Remove expired session
            self.removeSession(token) catch {
                logger.err("Failed to remove expired session: {s}", .{token});
            };
            return null;
        }
        
        return session;
    }
    
    pub fn removeSession(self: *AuthManager, token: []const u8) !void {
        // Get the session before removing it
        const session = self.sessions.get(token) orelse return;
        
        // Make copies of data we need for cleanup
        const session_copy = session;
        
        // Remove from map first - this handles the key cleanup automatically
        const removed = self.sessions.fetchRemove(token);
        if (removed) |entry| {
            // Free the key that was stored in the map
            self.allocator.free(entry.key);
            
            // Free the session data (username was allocated separately)
            self.allocator.free(session_copy.username);
            // Note: token is the same as the key, so it's already freed above
        }
        
        logger.debug("Session removed: {s}", .{token});
    }
    
    pub fn getUserFromSession(self: *AuthManager, token: []const u8) ?User {
        const session = self.validateSession(token) orelse return null;
        return self.users.get(session.username);
    }
    
    pub fn cleanupExpiredSessions(self: *AuthManager) !void {
        var expired_tokens = std.ArrayList([]const u8).init(self.allocator);
        defer expired_tokens.deinit();
        
        // Find expired sessions
        var session_iter = self.sessions.iterator();
        while (session_iter.next()) |entry| {
            if (entry.value_ptr.isExpired()) {
                try expired_tokens.append(entry.key_ptr.*);
            }
        }
        
        // Remove expired sessions
        for (expired_tokens.items) |token| {
            try self.removeSession(token);
        }
        
        if (expired_tokens.items.len > 0) {
            logger.info("Cleaned up {} expired sessions", .{expired_tokens.items.len});
        }
    }
    
    pub fn getSessionCount(self: *AuthManager) usize {
        return self.sessions.count();
    }
    
    pub fn getUserCount(self: *AuthManager) usize {
        return self.users.count();
    }
};

// Global auth manager instance
var auth_manager: ?AuthManager = null;

/// Initialize authentication system
pub fn init() void {
    const allocator = std.heap.page_allocator;
    auth_manager = AuthManager.init(allocator);
    
    auth_manager.?.initializeDefaultUser() catch |err| {
        logger.err("Failed to initialize default user: {}", .{err});
        return;
    };
    
    logger.info("Authentication system initialized", .{});
}

/// Cleanup authentication system
pub fn deinit() void {
    if (auth_manager) |*manager| {
        manager.deinit();
        auth_manager = null;
        logger.info("Authentication system cleaned up", .{});
    }
}

/// Authenticate user with credentials
pub fn authenticate(username: []const u8, password: []const u8) !errors.Result(Session) {
    if (auth_manager) |*manager| {
        return manager.authenticate(username, password);
    }
    return errors.Result(Session){ .err = errors.HttpError.init(.internal_server_error, "Authentication system not initialized") };
}

/// Validate session token
pub fn validateSession(token: []const u8) bool {
    if (auth_manager) |*manager| {
        return manager.validateSession(token) != null;
    }
    return false;
}

/// Get session from token
pub fn getSession(token: []const u8) ?Session {
    if (auth_manager) |*manager| {
        return manager.validateSession(token);
    }
    return null;
}

/// Remove session
pub fn removeSession(token: []const u8) void {
    if (auth_manager) |*manager| {
        manager.removeSession(token) catch |err| {
            logger.err("Failed to remove session: {}", .{err});
        };
    }
}

/// Create session for user
pub fn createSession(username: []const u8) ![]const u8 {
    if (auth_manager) |*manager| {
        const session = try manager.createSession(username);
        return session.token;
    }
    return errors.GitStationError.InternalError;
}

/// Get user from session token
pub fn getUserFromSession(token: []const u8) ?User {
    if (auth_manager) |*manager| {
        return manager.getUserFromSession(token);
    }
    return null;
}

/// Cleanup expired sessions (should be called periodically)
pub fn cleanupExpiredSessions() void {
    if (auth_manager) |*manager| {
        manager.cleanupExpiredSessions() catch |err| {
            logger.err("Failed to cleanup expired sessions: {}", .{err});
        };
    }
}

/// Get authentication statistics
pub fn getStats() struct { sessions: usize, users: usize } {
    if (auth_manager) |*manager| {
        return .{
            .sessions = manager.getSessionCount(),
            .users = manager.getUserCount(),
        };
    }
    return .{ .sessions = 0, .users = 0 };
}