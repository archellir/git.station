const std = @import("std");

/// Configuration constants for Git Station server
pub const Config = struct {
    // Server configuration
    pub const SERVER_HOST = "127.0.0.1";
    pub const SERVER_PORT: u16 = 8080;
    pub const SERVER_ADDRESS = SERVER_HOST ++ ":" ++ std.fmt.comptimePrint("{}", .{SERVER_PORT});
    
    // File paths
    pub const REPO_PATH = "./repositories";
    pub const STATIC_PATH = "../frontend/build";
    pub const DATABASE_PATH = "./data/git_station.db";
    
    // Network configuration
    pub const LISTEN_BACKLOG = 128;
    pub const REQUEST_BUFFER_SIZE = 8192;
    
    // Authentication configuration
    pub const ADMIN_USERNAME = "admin";
    pub const ADMIN_PASSWORD = "password123";
    pub const SESSION_TOKEN_LENGTH = 64;
    
    // HTTP configuration
    pub const MAX_HEADER_SIZE = 4096;
    pub const MAX_BODY_SIZE = 1024 * 1024; // 1MB
    
    // Database configuration
    pub const MAX_ISSUES_PER_REPO = 1000;
    pub const MAX_PULL_REQUESTS_PER_REPO = 1000;
};

/// Environment-specific configuration
pub const Environment = enum {
    development,
    production,
    testing,
    
    pub fn current() Environment {
        const env_var = std.posix.getenv("GIT_STATION_ENV") orelse "development";
        if (std.mem.eql(u8, env_var, "production")) return .production;
        if (std.mem.eql(u8, env_var, "testing")) return .testing;
        return .development;
    }
    
    pub fn isDevelopment(self: Environment) bool {
        return self == .development;
    }
    
    pub fn isProduction(self: Environment) bool {
        return self == .production;
    }
    
    pub fn isTesting(self: Environment) bool {
        return self == .testing;
    }
};

/// HTTP methods enum
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    OPTIONS,
    HEAD,
    
    pub fn fromString(method_str: []const u8) ?HttpMethod {
        if (std.mem.eql(u8, method_str, "GET")) return .GET;
        if (std.mem.eql(u8, method_str, "POST")) return .POST;
        if (std.mem.eql(u8, method_str, "PUT")) return .PUT;
        if (std.mem.eql(u8, method_str, "DELETE")) return .DELETE;
        if (std.mem.eql(u8, method_str, "PATCH")) return .PATCH;
        if (std.mem.eql(u8, method_str, "OPTIONS")) return .OPTIONS;
        if (std.mem.eql(u8, method_str, "HEAD")) return .HEAD;
        return null;
    }
    
    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .OPTIONS => "OPTIONS",
            .HEAD => "HEAD",
        };
    }
};

/// HTTP status codes
pub const HttpStatus = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    conflict = 409,
    internal_server_error = 500,
    not_implemented = 501,
    service_unavailable = 503,
    
    pub fn phrase(self: HttpStatus) []const u8 {
        return switch (self) {
            .ok => "OK",
            .created => "Created",
            .no_content => "No Content",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .conflict => "Conflict",
            .internal_server_error => "Internal Server Error",
            .not_implemented => "Not Implemented",
            .service_unavailable => "Service Unavailable",
        };
    }
};

/// Content types for HTTP responses
pub const ContentType = enum {
    json,
    html,
    css,
    javascript,
    text,
    binary,
    
    pub fn toString(self: ContentType) []const u8 {
        return switch (self) {
            .json => "application/json",
            .html => "text/html",
            .css => "text/css",
            .javascript => "application/javascript",
            .text => "text/plain",
            .binary => "application/octet-stream",
        };
    }
    
    pub fn fromExtension(ext: []const u8) ContentType {
        if (std.mem.eql(u8, ext, "html")) return .html;
        if (std.mem.eql(u8, ext, "css")) return .css;
        if (std.mem.eql(u8, ext, "js")) return .javascript;
        if (std.mem.eql(u8, ext, "json")) return .json;
        if (std.mem.eql(u8, ext, "txt")) return .text;
        return .binary;
    }
};