const std = @import("std");
const config = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const logger = @import("logger.zig");
const auth = @import("auth.zig");

/// Route handler function type
pub const RouteHandler = *const fn (request: *const http.Request, allocator: std.mem.Allocator) anyerror!http.Response;

/// Route definition
pub const Route = struct {
    method: config.HttpMethod,
    path: []const u8,
    handler: RouteHandler,
    requires_auth: bool = true,
    
    pub fn matches(self: Route, method: config.HttpMethod, path: []const u8) bool {
        return self.method == method and self.pathMatches(path);
    }
    
    fn pathMatches(self: Route, path: []const u8) bool {
        // Exact match
        if (std.mem.eql(u8, self.path, path)) {
            return true;
        }
        
        // Pattern matching for dynamic routes
        return self.matchPattern(path);
    }
    
    fn matchPattern(self: Route, path: []const u8) bool {
        // Simple pattern matching for routes like "/api/repo/{name}"
        var self_parts = std.mem.split(u8, self.path, "/");
        var path_parts = std.mem.split(u8, path, "/");
        
        while (true) {
            const self_part = self_parts.next();
            const path_part = path_parts.next();
            
            // Both reached end - match
            if (self_part == null and path_part == null) {
                return true;
            }
            
            // One reached end but not the other - no match
            if (self_part == null or path_part == null) {
                return false;
            }
            
            // Check if this part matches
            if (!self.partMatches(self_part.?, path_part.?)) {
                return false;
            }
        }
    }
    
    fn partMatches(self: Route, pattern_part: []const u8, path_part: []const u8) bool {
        _ = self;
        
        // Dynamic parameter (e.g., {name})
        if (pattern_part.len > 2 and pattern_part[0] == '{' and pattern_part[pattern_part.len - 1] == '}') {
            return path_part.len > 0;
        }
        
        // Exact match
        return std.mem.eql(u8, pattern_part, path_part);
    }
};

/// Router instance
pub const Router = struct {
    routes: std.ArrayList(Route),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Router {
        return Router{
            .routes = std.ArrayList(Route).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Router) void {
        self.routes.deinit();
    }
    
    pub fn addRoute(self: *Router, route: Route) !void {
        try self.routes.append(route);
    }
    
    pub fn get(self: *Router, path: []const u8, handler: RouteHandler, requires_auth: bool) !void {
        try self.addRoute(Route{
            .method = .GET,
            .path = path,
            .handler = handler,
            .requires_auth = requires_auth,
        });
    }
    
    pub fn post(self: *Router, path: []const u8, handler: RouteHandler, requires_auth: bool) !void {
        try self.addRoute(Route{
            .method = .POST,
            .path = path,
            .handler = handler,
            .requires_auth = requires_auth,
        });
    }
    
    pub fn put(self: *Router, path: []const u8, handler: RouteHandler, requires_auth: bool) !void {
        try self.addRoute(Route{
            .method = .PUT,
            .path = path,
            .handler = handler,
            .requires_auth = requires_auth,
        });
    }
    
    pub fn delete(self: *Router, path: []const u8, handler: RouteHandler, requires_auth: bool) !void {
        try self.addRoute(Route{
            .method = .DELETE,
            .path = path,
            .handler = handler,
            .requires_auth = requires_auth,
        });
    }
    
    pub fn handleRequest(self: *Router, connection: http.Connection, request: *const http.Request) void {
        const start_time = std.time.milliTimestamp();
        
        // Find matching route
        const route = self.findRoute(request.method, request.path);
        
        if (route == null) {
            // No route found
            const error_response = errors.HttpError.init(.not_found, "Route not found");
            connection.writeError(error_response, self.allocator);
            self.logRequest(request, 404, start_time);
            return;
        }
        
        const matched_route = route.?;
        
        // Check authentication if required
        if (matched_route.requires_auth) {
            const auth_token = http.getCookie(request, "session") orelse "";
            const is_authenticated = auth_token.len > 0 and auth.validateSession(auth_token);
            
            if (!is_authenticated) {
                const error_response = errors.HttpError.init(.unauthorized, "Authentication required");
                connection.writeError(error_response, self.allocator);
                self.logRequest(request, 401, start_time);
                return;
            }
        }
        
        // Call the handler
        const response = matched_route.handler(request, self.allocator) catch |err| {
            const http_error = errors.toHttpError(err);
            connection.writeError(http_error, self.allocator);
            self.logRequest(request, @intFromEnum(http_error.status), start_time);
            logger.logError(err, "Route handler failed");
            return;
        };
        
        // Send response
        connection.writeResponse(response) catch |err| {
            logger.logError(err, "Failed to send response");
            return;
        };
        
        self.logRequest(request, @intFromEnum(response.status), start_time);
    }
    
    fn findRoute(self: *Router, method: config.HttpMethod, path: []const u8) ?Route {
        for (self.routes.items) |route| {
            if (route.matches(method, path)) {
                return route;
            }
        }
        return null;
    }
    
    fn logRequest(self: *Router, request: *const http.Request, status: u16, start_time: i64) void {
        _ = self;
        const end_time = std.time.milliTimestamp();
        const duration = @as(u64, @intCast(end_time - start_time));
        logger.logRequest(request.method.toString(), request.path, status, duration);
    }
};

/// Path parameter extraction utilities
pub const PathParams = struct {
    params: std.StringHashMap([]const u8),
    
    pub fn init(allocator: std.mem.Allocator) PathParams {
        return PathParams{
            .params = std.StringHashMap([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *PathParams) void {
        self.params.deinit();
    }
    
    pub fn get(self: *const PathParams, name: []const u8) ?[]const u8 {
        return self.params.get(name);
    }
    
    pub fn extract(allocator: std.mem.Allocator, pattern: []const u8, path: []const u8) !PathParams {
        var params = PathParams.init(allocator);
        
        var pattern_parts = std.mem.split(u8, pattern, "/");
        var path_parts = std.mem.split(u8, path, "/");
        
        while (true) {
            const pattern_part = pattern_parts.next();
            const path_part = path_parts.next();
            
            if (pattern_part == null or path_part == null) {
                break;
            }
            
            // Check if this is a parameter
            if (pattern_part.?.len > 2 and pattern_part.?[0] == '{' and pattern_part.?[pattern_part.?.len - 1] == '}') {
                const param_name = pattern_part.?[1 .. pattern_part.?.len - 1];
                const param_value = try allocator.dupe(u8, path_part.?);
                try params.params.put(param_name, param_value);
            }
        }
        
        return params;
    }
};

/// Middleware function type
pub const Middleware = *const fn (request: *http.Request, next: *const fn () anyerror!http.Response) anyerror!http.Response;

/// Middleware stack
pub const MiddlewareStack = struct {
    middlewares: std.ArrayList(Middleware),
    
    pub fn init(allocator: std.mem.Allocator) MiddlewareStack {
        return MiddlewareStack{
            .middlewares = std.ArrayList(Middleware).init(allocator),
        };
    }
    
    pub fn deinit(self: *MiddlewareStack) void {
        self.middlewares.deinit();
    }
    
    pub fn use(self: *MiddlewareStack, middleware: Middleware) !void {
        try self.middlewares.append(middleware);
    }
    
    pub fn execute(self: *MiddlewareStack, request: *http.Request, final_handler: RouteHandler, allocator: std.mem.Allocator) !http.Response {
        _ = self;
        _ = request;
        _ = allocator;
        
        // For now, just call the final handler
        // TODO: Implement middleware chain execution
        return final_handler(request, allocator);
    }
};