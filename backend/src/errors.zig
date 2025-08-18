const std = @import("std");
const config = @import("config.zig");

/// Unified error types for Git Station
pub const GitStationError = error{
    // Network errors
    NetworkError,
    ConnectionFailed,
    InvalidRequest,
    RequestTooLarge,
    
    // Authentication errors
    AuthenticationFailed,
    InvalidCredentials,
    SessionExpired,
    Unauthorized,
    
    // Git operation errors
    GitOperationFailed,
    RepositoryNotFound,
    BranchNotFound,
    FileNotFound,
    InvalidPath,
    
    // Database errors
    DatabaseError,
    DatabaseConnectionFailed,
    QueryFailed,
    DataCorruption,
    
    // File system errors
    FileSystemError,
    PermissionDenied,
    DirectoryNotFound,
    
    // General errors
    OutOfMemory,
    InvalidInput,
    InternalError,
    NotImplemented,
    
    // HTTP specific errors
    InvalidHttpMethod,
    InvalidHttpHeaders,
    UnsupportedMediaType,
};

/// HTTP Error response structure
pub const HttpError = struct {
    status: config.HttpStatus,
    message: []const u8,
    details: ?[]const u8 = null,
    
    pub fn init(status: config.HttpStatus, message: []const u8) HttpError {
        return HttpError{
            .status = status,
            .message = message,
        };
    }
    
    pub fn initWithDetails(status: config.HttpStatus, message: []const u8, details: []const u8) HttpError {
        return HttpError{
            .status = status,
            .message = message,
            .details = details,
        };
    }
    
    pub fn toJson(self: HttpError, allocator: std.mem.Allocator) ![]const u8 {
        if (self.details) |details| {
            return try std.fmt.allocPrint(allocator, 
                "{{\"error\": \"{s}\", \"message\": \"{s}\", \"details\": \"{s}\"}}", 
                .{ self.status.phrase(), self.message, details });
        } else {
            return try std.fmt.allocPrint(allocator, 
                "{{\"error\": \"{s}\", \"message\": \"{s}\"}}", 
                .{ self.status.phrase(), self.message });
        }
    }
};

/// Convert Zig errors to HTTP errors
pub fn toHttpError(err: anyerror) HttpError {
    return switch (err) {
        GitStationError.AuthenticationFailed,
        GitStationError.InvalidCredentials => HttpError.init(.unauthorized, "Authentication failed"),
        GitStationError.SessionExpired => HttpError.init(.unauthorized, "Session expired"),
        GitStationError.Unauthorized => HttpError.init(.unauthorized, "Unauthorized access"),
        
        GitStationError.RepositoryNotFound,
        GitStationError.BranchNotFound,
        GitStationError.FileNotFound => HttpError.init(.not_found, "Resource not found"),
        
        GitStationError.InvalidRequest,
        GitStationError.InvalidInput,
        GitStationError.InvalidPath => HttpError.init(.bad_request, "Invalid request"),
        
        GitStationError.InvalidHttpMethod => HttpError.init(.method_not_allowed, "Method not allowed"),
        GitStationError.UnsupportedMediaType => HttpError.init(.bad_request, "Unsupported media type"),
        GitStationError.RequestTooLarge => HttpError.init(.bad_request, "Request too large"),
        
        GitStationError.PermissionDenied => HttpError.init(.forbidden, "Permission denied"),
        
        GitStationError.NotImplemented => HttpError.init(.not_implemented, "Feature not implemented"),
        
        GitStationError.OutOfMemory => HttpError.init(.internal_server_error, "Out of memory"),
        GitStationError.DatabaseError,
        GitStationError.DatabaseConnectionFailed,
        GitStationError.QueryFailed,
        GitStationError.GitOperationFailed,
        GitStationError.FileSystemError,
        GitStationError.InternalError => HttpError.init(.internal_server_error, "Internal server error"),
        
        else => HttpError.init(.internal_server_error, "Unknown error occurred"),
    };
}

/// Error context for debugging
pub const ErrorContext = struct {
    file: []const u8,
    function: []const u8,
    line: u32,
    
    pub fn init(comptime file: []const u8, comptime function: []const u8, comptime line: u32) ErrorContext {
        return ErrorContext{
            .file = file,
            .function = function,
            .line = line,
        };
    }
    
    pub fn log(self: ErrorContext, err: anyerror, message: []const u8) void {
        const env = config.Environment.current();
        if (env.isDevelopment()) {
            std.debug.print("[ERROR] {s}:{s}:{} - {s}: {}\n", .{ self.file, self.function, self.line, message, err });
        } else {
            std.debug.print("[ERROR] {s}: {}\n", .{ message, err });
        }
    }
};

/// Macro for creating error context
pub fn errorContext(comptime function: []const u8) ErrorContext {
    return ErrorContext.init(@src().file, function, @src().line);
}

/// Result type for operations that can fail
pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: HttpError,
        
        pub fn isOk(self: @This()) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }
        
        pub fn isErr(self: @This()) bool {
            return !self.isOk();
        }
        
        pub fn unwrap(self: @This()) T {
            return switch (self) {
                .ok => |value| value,
                .err => |http_err| std.debug.panic("Called unwrap on error: {s}", .{http_err.message}),
            };
        }
        
        pub fn unwrapOr(self: @This(), default: T) T {
            return switch (self) {
                .ok => |value| value,
                .err => default,
            };
        }
    };
}