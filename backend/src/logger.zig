const std = @import("std");
const config = @import("config.zig");

/// Log levels
pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,
    fatal = 4,
    
    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }
    
    pub fn color(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "\x1b[36m", // Cyan
            .info => "\x1b[32m",  // Green
            .warn => "\x1b[33m",  // Yellow
            .err => "\x1b[31m",   // Red
            .fatal => "\x1b[35m", // Magenta
        };
    }
};

/// Logger configuration
pub const LoggerConfig = struct {
    level: LogLevel = .info,
    use_colors: bool = true,
    timestamp: bool = true,
    source_info: bool = false,
};

/// Global logger instance
var logger_config: LoggerConfig = LoggerConfig{};

/// Initialize logger with configuration
pub fn init(config_opt: ?LoggerConfig) void {
    if (config_opt) |cfg| {
        logger_config = cfg;
    }
    
    // Set log level based on environment
    const env = config.Environment.current();
    if (env.isDevelopment()) {
        logger_config.level = .debug;
        logger_config.source_info = true;
    } else if (env.isProduction()) {
        logger_config.level = .info;
        logger_config.use_colors = false;
        logger_config.source_info = false;
    }
}

/// Get current timestamp as string
fn getTimestamp(allocator: std.mem.Allocator) ![]const u8 {
    const now = std.time.timestamp();
    
    // Simple timestamp format for now
    return try std.fmt.allocPrint(allocator, "{}", .{now});
}

/// Core logging function
fn logMessage(
    comptime level: LogLevel,
    comptime format: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    // Check if we should log this level
    if (@intFromEnum(level) < @intFromEnum(logger_config.level)) {
        return;
    }
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Build log message
    var message = std.ArrayList(u8).init(allocator);
    defer message.deinit();
    
    const writer = message.writer();
    
    // Add color if enabled
    if (logger_config.use_colors) {
        writer.print("{s}", .{level.color()}) catch return;
    }
    
    // Add timestamp if enabled
    if (logger_config.timestamp) {
        const timestamp = getTimestamp(allocator) catch "UNKNOWN";
        writer.print("[{s}] ", .{timestamp}) catch return;
    }
    
    // Add log level
    writer.print("[{s}] ", .{level.toString()}) catch return;
    
    // Add source info if enabled
    if (logger_config.source_info) {
        const file_name = std.fs.path.basename(src.file);
        writer.print("{s}:{s}:{} ", .{ file_name, src.fn_name, src.line }) catch return;
    }
    
    // Add the actual message
    writer.print(format, args) catch return;
    
    // Reset color if enabled
    if (logger_config.use_colors) {
        writer.print("\x1b[0m", .{}) catch return;
    }
    
    // Add newline
    writer.print("\n", .{}) catch return;
    
    // Output to stderr for errors, stdout for everything else
    const output = if (level == .err or level == .fatal) std.io.getStdErr() else std.io.getStdOut();
    output.writeAll(message.items) catch return;
}

/// Public logging functions
pub fn debug(comptime format: []const u8, args: anytype) void {
    logMessage(.debug, format, args, @src());
}

pub fn info(comptime format: []const u8, args: anytype) void {
    logMessage(.info, format, args, @src());
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    logMessage(.warn, format, args, @src());
}

pub fn err(comptime format: []const u8, args: anytype) void {
    logMessage(.err, format, args, @src());
}

pub fn fatal(comptime format: []const u8, args: anytype) void {
    logMessage(.fatal, format, args, @src());
}

/// Log HTTP requests
pub fn logRequest(method: []const u8, path: []const u8, status: u16, duration_ms: ?u64) void {
    if (duration_ms) |ms| {
        info("{s} {s} - {} ({}ms)", .{ method, path, status, ms });
    } else {
        info("{s} {s} - {}", .{ method, path, status });
    }
}

/// Log errors with context
pub fn logError(error_value: anyerror, context: []const u8) void {
    err("{s}: {}", .{ context, error_value });
}

/// Log startup information
pub fn logStartup(address: []const u8) void {
    info("Git Station server starting...", .{});
    info("Environment: {s}", .{@tagName(config.Environment.current())});
    info("Listening on: http://{s}", .{address});
    info("Repository path: {s}", .{config.Config.REPO_PATH});
    info("Static files: {s}", .{config.Config.STATIC_PATH});
}

/// Log shutdown information
pub fn logShutdown() void {
    info("Git Station server shutting down...", .{});
}