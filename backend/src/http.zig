const std = @import("std");
const config = @import("config.zig");
const errors = @import("errors.zig");
const logger = @import("logger.zig");

/// HTTP Request structure
pub const Request = struct {
    method: config.HttpMethod,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    query_params: std.StringHashMap([]const u8),
    
    pub fn init(allocator: std.mem.Allocator) Request {
        return Request{
            .method = .GET,
            .path = "",
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
            .query_params = std.StringHashMap([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *Request) void {
        self.headers.deinit();
        self.query_params.deinit();
    }
    
    pub fn getHeader(self: *const Request, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }
    
    pub fn getQueryParam(self: *const Request, name: []const u8) ?[]const u8 {
        return self.query_params.get(name);
    }
    
    pub fn hasHeader(self: *const Request, name: []const u8) bool {
        return self.headers.contains(name);
    }
    
    pub fn getContentType(self: *const Request) ?config.ContentType {
        const content_type_header = self.getHeader("content-type") orelse return null;
        
        if (std.mem.indexOf(u8, content_type_header, "application/json") != null) {
            return .json;
        } else if (std.mem.indexOf(u8, content_type_header, "text/html") != null) {
            return .html;
        } else if (std.mem.indexOf(u8, content_type_header, "text/css") != null) {
            return .css;
        } else if (std.mem.indexOf(u8, content_type_header, "application/javascript") != null) {
            return .javascript;
        } else if (std.mem.indexOf(u8, content_type_header, "text/plain") != null) {
            return .text;
        }
        
        return .binary;
    }
};

/// HTTP Response structure
pub const Response = struct {
    status: config.HttpStatus,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    
    pub fn init(allocator: std.mem.Allocator) Response {
        return Response{
            .status = .ok,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
        };
    }
    
    pub fn deinit(self: *Response) void {
        self.headers.deinit();
    }
    
    pub fn setHeader(self: *Response, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }
    
    pub fn setContentType(self: *Response, content_type: config.ContentType) !void {
        try self.setHeader("Content-Type", content_type.toString());
    }
    
    pub fn setJsonBody(self: *Response, allocator: std.mem.Allocator, json: []const u8) !void {
        self.body = try allocator.dupe(u8, json);
        try self.setContentType(.json);
    }
    
    pub fn setTextBody(self: *Response, allocator: std.mem.Allocator, text: []const u8) !void {
        self.body = try allocator.dupe(u8, text);
        try self.setContentType(.text);
    }
    
    pub fn setHtmlBody(self: *Response, allocator: std.mem.Allocator, html: []const u8) !void {
        self.body = try allocator.dupe(u8, html);
        try self.setContentType(.html);
    }
};

/// HTTP Connection wrapper
pub const Connection = struct {
    stream: std.net.Stream,
    address: std.net.Address,
    
    pub fn init(stream: std.net.Stream, address: std.net.Address) Connection {
        return Connection{
            .stream = stream,
            .address = address,
        };
    }
    
    pub fn close(self: Connection) void {
        self.stream.close();
    }
    
    pub fn readRequest(self: Connection, allocator: std.mem.Allocator) !Request {
        var buffer: [config.Config.REQUEST_BUFFER_SIZE]u8 = undefined;
        
        const bytes_read = self.stream.read(&buffer) catch |err| {
            logger.err("Failed to read request: {}", .{err});
            return errors.GitStationError.NetworkError;
        };
        
        if (bytes_read == 0) {
            return errors.GitStationError.InvalidRequest;
        }
        
        const request_data = buffer[0..bytes_read];
        return parseRequest(allocator, request_data);
    }
    
    pub fn writeResponse(self: Connection, response: Response) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        
        // Build HTTP response
        var response_data = std.ArrayList(u8).init(allocator);
        defer response_data.deinit();
        
        const writer = response_data.writer();
        
        // Status line
        try writer.print("HTTP/1.1 {} {s}\r\n", .{ @intFromEnum(response.status), response.status.phrase() });
        
        // Headers
        var header_iter = response.headers.iterator();
        while (header_iter.next()) |entry| {
            try writer.print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        
        // Content-Length header if body exists
        if (response.body) |body| {
            try writer.print("Content-Length: {}\r\n", .{body.len});
        }
        
        // End of headers
        try writer.print("\r\n");
        
        // Body
        if (response.body) |body| {
            try writer.writeAll(body);
        }
        
        // Send response
        try self.stream.writeAll(response_data.items);
    }
    
    pub fn writeError(self: Connection, http_error: errors.HttpError, allocator: std.mem.Allocator) void {
        var response = Response.init(allocator);
        defer response.deinit();
        
        response.status = http_error.status;
        
        const json_body = http_error.toJson(allocator) catch {
            // Fallback if JSON serialization fails
            const fallback = "{\"error\": \"Internal Server Error\"}";
            response.setJsonBody(allocator, fallback) catch return;
            self.writeResponse(response) catch return;
            return;
        };
        
        response.setJsonBody(allocator, json_body) catch return;
        self.writeResponse(response) catch return;
    }
};

/// Parse HTTP request from raw data
pub fn parseRequest(allocator: std.mem.Allocator, data: []const u8) !Request {
    var request = Request.init(allocator);
    
    // Find the end of the first line (method and path)
    const first_line_end = std.mem.indexOf(u8, data, "\r\n") orelse {
        return errors.GitStationError.InvalidRequest;
    };
    
    const first_line = data[0..first_line_end];
    
    // Parse method and path
    const space_pos = std.mem.indexOf(u8, first_line, " ") orelse {
        return errors.GitStationError.InvalidRequest;
    };
    
    const method_str = first_line[0..space_pos];
    request.method = config.HttpMethod.fromString(method_str) orelse {
        return errors.GitStationError.InvalidHttpMethod;
    };
    
    const path_start = space_pos + 1;
    const path_end = std.mem.lastIndexOf(u8, first_line, " ") orelse first_line.len;
    const full_path = first_line[path_start..path_end];
    
    // Parse path and query parameters
    if (std.mem.indexOf(u8, full_path, "?")) |query_start| {
        request.path = full_path[0..query_start];
        const query_string = full_path[query_start + 1 ..];
        try parseQueryParams(&request, allocator, query_string);
    } else {
        request.path = full_path;
    }
    
    // Parse headers
    const headers_start = first_line_end + 2;
    const headers_end = std.mem.indexOf(u8, data[headers_start..], "\r\n\r\n") orelse data.len - headers_start;
    const headers_section = data[headers_start .. headers_start + headers_end];
    
    try parseHeaders(&request, allocator, headers_section);
    
    // Parse body if present
    const body_start = headers_start + headers_end + 4;
    if (body_start < data.len) {
        request.body = data[body_start..];
    }
    
    return request;
}

/// Parse query parameters
fn parseQueryParams(request: *Request, allocator: std.mem.Allocator, query_string: []const u8) !void {
    var param_iter = std.mem.split(u8, query_string, "&");
    
    while (param_iter.next()) |param| {
        if (std.mem.indexOf(u8, param, "=")) |eq_pos| {
            const key = param[0..eq_pos];
            const value = param[eq_pos + 1 ..];
            
            // URL decode key and value
            const decoded_key = try allocator.dupe(u8, key);
            const decoded_value = try allocator.dupe(u8, value);
            
            try request.query_params.put(decoded_key, decoded_value);
        }
    }
}

/// Parse HTTP headers
fn parseHeaders(request: *Request, allocator: std.mem.Allocator, headers_data: []const u8) !void {
    var line_iter = std.mem.split(u8, headers_data, "\r\n");
    
    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        
        if (std.mem.indexOf(u8, line, ": ")) |colon_pos| {
            const name = line[0..colon_pos];
            const value = line[colon_pos + 2 ..];
            
            // Convert header name to lowercase for case-insensitive lookup
            const lower_name = try allocator.alloc(u8, name.len);
            for (name, 0..) |c, i| {
                lower_name[i] = std.ascii.toLower(c);
            }
            
            const owned_value = try allocator.dupe(u8, value);
            try request.headers.put(lower_name, owned_value);
        }
    }
}

/// Extract cookie value from request
pub fn getCookie(request: *const Request, name: []const u8) ?[]const u8 {
    const cookie_header = request.getHeader("cookie") orelse return null;
    
    // Simple cookie parsing - look for "name=value"
    const cookie_start = std.mem.indexOf(u8, cookie_header, name) orelse return null;
    const value_start = cookie_start + name.len + 1; // +1 for '='
    
    if (value_start >= cookie_header.len) return null;
    
    const value_end = std.mem.indexOf(u8, cookie_header[value_start..], ";") orelse cookie_header.len - value_start;
    
    return cookie_header[value_start .. value_start + value_end];
}

/// Create a cookie string
pub fn createCookie(allocator: std.mem.Allocator, name: []const u8, value: []const u8, max_age: ?u32) ![]const u8 {
    if (max_age) |age| {
        return try std.fmt.allocPrint(allocator, "{s}={s}; Max-Age={}; HttpOnly; SameSite=Strict", .{ name, value, age });
    } else {
        return try std.fmt.allocPrint(allocator, "{s}={s}; HttpOnly; SameSite=Strict", .{ name, value });
    }
}