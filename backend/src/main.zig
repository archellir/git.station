const std = @import("std");
const git = @import("git.zig");
const c = @cImport({
    @cInclude("git2.h");
});

// Repository storage path
const REPO_PATH = "./repositories";

pub fn main() !void {
    // Initialize Git
    git.init();
    defer git.deinit();

    // Ensure repository directory exists
    try std.fs.cwd().makePath(REPO_PATH);

    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create HTTP server
    const address = try std.net.Address.parseIp("127.0.0.1", 8080);
    var server = std.net.StreamServer.init(.{});
    defer server.deinit();

    try server.listen(address);
    std.debug.print("Git service listening on http://{}\n", .{address});

    // Accept connections in a loop
    while (true) {
        const connection = try server.accept();

        // Handle each connection in a separate thread
        const conn_thread = try std.Thread.spawn(.{}, handleConnection, .{ connection, allocator });
        conn_thread.detach();
    }
}

fn handleConnection(connection: std.net.StreamServer.Connection, allocator: std.mem.Allocator) !void {
    defer connection.stream.close();

    // Buffer for reading HTTP request
    var buffer: [4096]u8 = undefined;
    const bytes_read = try connection.stream.read(&buffer);

    if (bytes_read == 0) return;

    // Parse HTTP request (very basic)
    const request = buffer[0..bytes_read];

    // Check if this is a GET request
    if (std.mem.startsWith(u8, request, "GET")) {
        if (std.mem.indexOf(u8, request, "GET /api/repos") != null) {
            try handleListRepositories(connection, allocator);
        } else if (std.mem.indexOf(u8, request, "GET /api/repo/") != null) {
            // Extract repo name from path
            const start = std.mem.indexOf(u8, request, "GET /api/repo/").? + "GET /api/repo/".len;
            const end = std.mem.indexOfPos(u8, request, start, " ") orelse bytes_read;
            const repo_name = request[start .. start + end];

            try handleGetRepository(connection, allocator, repo_name);
        } else {
            // Serve welcome page
            try serveWelcomePage(connection);
        }
    } else if (std.mem.startsWith(u8, request, "POST")) {
        if (std.mem.indexOf(u8, request, "POST /api/repos") != null) {
            // Extract repo name from request body
            const body_start = std.mem.indexOf(u8, request, "\r\n\r\n").? + 4;
            const body = request[body_start..bytes_read];

            // Very simple JSON parsing
            if (std.mem.indexOf(u8, body, "\"name\":")) |name_pos| {
                const start = name_pos + "\"name\":".len;
                const quote_start = std.mem.indexOfPos(u8, body, start, "\"").? + 1;
                const quote_end = std.mem.indexOfPos(u8, body, quote_start, "\"").?;
                const repo_name = body[quote_start..quote_end];

                try handleCreateRepository(connection, allocator, repo_name);
            } else {
                try sendJsonResponse(connection, 400, "Invalid request: missing repository name");
            }
        } else {
            try sendJsonResponse(connection, 404, "Endpoint not found");
        }
    } else {
        try sendJsonResponse(connection, 405, "Method not allowed");
    }
}

fn handleListRepositories(connection: std.net.StreamServer.Connection, allocator: std.mem.Allocator) !void {
    // List all repositories
    const repos = try git.listRepositories(REPO_PATH, allocator);
    defer {
        for (repos) |repo| {
            allocator.free(repo);
        }
        allocator.free(repos);
    }

    // Build JSON response
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.appendSlice("{\"repositories\":[");

    for (repos, 0..) |repo, i| {
        try response.appendSlice("\"");
        try response.appendSlice(repo);
        try response.appendSlice("\"");

        if (i < repos.len - 1) {
            try response.appendSlice(",");
        }
    }

    try response.appendSlice("]}");

    // Send response
    const json = try response.toOwnedSlice();
    defer allocator.free(json);

    try sendJsonResponse(connection, 200, json);
}

fn handleGetRepository(connection: std.net.StreamServer.Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    // Build repository path
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    // Try to open the repository
    const repo = git.openRepository(repo_path, allocator) catch {
        return sendJsonResponse(connection, 404, "Repository not found");
    };
    defer c.git_repository_free(repo);

    // Send basic repo info
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.appendSlice("{\"name\":\"");
    try response.appendSlice(repo_name);
    try response.appendSlice("\",\"path\":\"");
    try response.appendSlice(repo_path);
    try response.appendSlice("\"}");

    const json = try response.toOwnedSlice();
    defer allocator.free(json);

    try sendJsonResponse(connection, 200, json);
}

fn handleCreateRepository(connection: std.net.StreamServer.Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    // Build repository path
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    // Create the repository
    git.createRepository(repo_path, allocator) catch {
        return sendJsonResponse(connection, 500, "Failed to create repository");
    };

    const response = try std.fmt.allocPrint(allocator, "{{\"status\":\"created\",\"name\":\"{s}\"}}", .{repo_name});
    defer allocator.free(response);

    try sendJsonResponse(connection, 201, response);
}

fn serveWelcomePage(connection: std.net.StreamServer.Connection) !void {
    const html =
        \\HTTP/1.1 200 OK
        \\Content-Type: text/html
        \\Connection: close
        \\
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\  <title>Zig Git Service</title>
        \\  <style>
        \\    body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; }
        \\    h1 { color: #2563EB; }
        \\    .btn { background: #2563EB; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; text-decoration: none; display: inline-block; }
        \\    pre { background: #f1f5f9; padding: 1rem; border-radius: 0.25rem; overflow: auto; }
        \\  </style>
        \\</head>
        \\<body>
        \\  <h1>Zig Git Service</h1>
        \\  <p>Your minimal Git service is running!</p>
        \\  
        \\  <h2>API Endpoints:</h2>
        \\  <ul>
        \\    <li><code>GET /api/repos</code> - List all repositories</li>
        \\    <li><code>POST /api/repos</code> - Create a new repository</li>
        \\    <li><code>GET /api/repo/{name}</code> - Get repository info</li>
        \\  </ul>
        \\  
        \\  <h2>Example Usage:</h2>
        \\  <pre>
        \\# Create a new repository
        \\curl -X POST -H "Content-Type: application/json" -d '{"name":"example"}' http://localhost:8080/api/repos
        \\
        \\# List all repositories
        \\curl http://localhost:8080/api/repos
        \\  </pre>
        \\</body>
        \\</html>
        \\
    ;

    _ = try connection.stream.write(html);
}

fn sendJsonResponse(connection: std.net.StreamServer.Connection, status: u16, json: []const u8) !void {
    var header_buf: [256]u8 = undefined;

    // Determine status message
    const status_msg = switch (status) {
        200 => "OK",
        201 => "Created",
        400 => "Bad Request",
        404 => "Not Found",
        405 => "Method Not Allowed",
        500 => "Internal Server Error",
        else => "Unknown",
    };

    // Format HTTP header
    const header = try std.fmt.bufPrint(&header_buf,
        \\HTTP/1.1 {d} {s}
        \\Content-Type: application/json
        \\Content-Length: {d}
        \\Connection: close
        \\Access-Control-Allow-Origin: *
        \\
        \\
    , .{ status, status_msg, json.len });

    _ = try connection.stream.write(header);
    _ = try connection.stream.write(json);
}
