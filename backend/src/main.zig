const std = @import("std");
const git = @import("git.zig");

const REPO_PATH = "./repositories";
const SERVER_ADDRESS = "127.0.0.1:8080";

const Connection = struct {
    stream: std.net.Stream,
    address: std.net.Address,
};

pub fn main() !void {
    git.init();
    defer git.deinit();

    try std.fs.cwd().makePath(REPO_PATH);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try std.net.Address.parseIp("127.0.0.1", 8080);
    const sockfd = try std.posix.socket(
        address.any.family,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC,
        std.posix.IPPROTO.TCP,
    );
    defer std.posix.close(sockfd);

    try std.posix.bind(sockfd, &address.any, address.getOsSockLen());
    try std.posix.listen(sockfd, 128);

    std.debug.print("Git service listening on http://{s}\n", .{SERVER_ADDRESS});

    while (true) {
        var client_addr: std.net.Address = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

        const client_fd = try std.posix.accept(
            sockfd,
            &client_addr.any,
            &addr_len,
            std.posix.SOCK.CLOEXEC,
        );

        const conn = Connection{
            .stream = .{ .handle = client_fd },
            .address = client_addr,
        };

        const thread = try std.Thread.spawn(.{}, handleConnection, .{ conn, allocator });
        thread.detach();
    }
}

fn handleConnection(conn: Connection, allocator: std.mem.Allocator) void {
    defer conn.stream.close();

    var buffer: [4096]u8 = undefined;
    const bytes_read = conn.stream.read(&buffer) catch |err| {
        std.debug.print("Failed to read request: {}\n", .{err});
        return;
    };

    if (bytes_read == 0) return;

    const request = buffer[0..bytes_read];
    const method = parseMethod(request) orelse return sendError(conn, 400, "Invalid request method");
    const path = parsePath(request) orelse return sendError(conn, 400, "Invalid request path");

    if (std.mem.eql(u8, method, "GET")) {
        if (std.mem.eql(u8, path, "/api/repos")) {
            handleListRepos(conn, allocator) catch return sendError(conn, 500, "Failed to list repos");
        } else if (std.mem.startsWith(u8, path, "/api/repo/")) {
            const repo_name = path["/api/repo/".len..];
            handleGetRepo(conn, allocator, repo_name) catch return sendError(conn, 500, "Failed to get repo");
        } else {
            serveWelcomePage(conn) catch return sendError(conn, 500, "Failed to serve welcome page");
        }
    } else if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/api/repos")) {
        const repo_name = parseRepoNameFromBody(request, allocator) catch return sendError(conn, 400, "Invalid repo name in request body");
        defer allocator.free(repo_name);
        handleCreateRepo(conn, allocator, repo_name) catch return sendError(conn, 500, "Failed to create repo");
    } else {
        sendError(conn, 405, "Method not allowed");
    }
}

fn parseMethod(request: []const u8) ?[]const u8 {
    if (request.len < 4) return null;
    return request[0 .. std.mem.indexOf(u8, request, " ") orelse return null];
}

fn parsePath(request: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, request, " ") orelse return null;
    const end = std.mem.indexOfPos(u8, request, start + 1, " ") orelse return null;
    return request[start + 1 .. end];
}

fn parseRepoNameFromBody(request: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];
    const name_start = std.mem.indexOf(u8, body, "\"name\":") orelse return error.NoName;
    const quote_start = std.mem.indexOfPos(u8, body, name_start + "\"name\":".len, "\"") orelse return error.InvalidJson;
    const quote_end = std.mem.indexOfPos(u8, body, quote_start + 1, "\"") orelse return error.InvalidJson;
    return try allocator.dupe(u8, body[quote_start + 1 .. quote_end]);
}

fn handleListRepos(conn: Connection, allocator: std.mem.Allocator) !void {
    const repos = try git.listRepositories(REPO_PATH, allocator);
    defer {
        for (repos) |repo| allocator.free(repo);
        allocator.free(repos);
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.writer().writeAll("{\"repositories\":[");
    for (repos, 0..) |repo, i| {
        try json.writer().print("\"{s}\"", .{repo});
        if (i < repos.len - 1) try json.writer().writeAll(",");
    }
    try json.writer().writeAll("]}");

    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleGetRepo(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    const repo = try git.openRepository(repo_path, allocator);
    defer git.freeRepository(repo);

    const json = try std.fmt.allocPrint(allocator, "{{\"name\":\"{s}\",\"path\":\"{s}\"}}", .{ repo_name, repo_path });
    defer allocator.free(json);
    try sendJsonResponse(conn, 200, json);
}

fn handleCreateRepo(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    try git.createRepository(repo_path, allocator);
    const json = try std.fmt.allocPrint(allocator, "{{\"status\":\"created\",\"name\":\"{s}\"}}", .{repo_name});
    defer allocator.free(json);
    try sendJsonResponse(conn, 201, json);
}

fn serveWelcomePage(conn: Connection) !void {
    const html =
        \\HTTP/1.1 200 OK
        \\Content-Type: text/html
        \\Connection: close
        \\
        \\<!DOCTYPE html>
        \\<html><head><title>Zig Git Service</title><style>
        \\body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; }
        \\h1 { color: #2563EB; }
        \\.btn { background: #2563EB; color: white; padding: 0.5rem 1rem; border-radius: 0.25rem; text-decoration: none; display: inline-block; }
        \\pre { background: #f1f5f9; padding: 1rem; border-radius: 0.25rem; overflow: auto; }
        \\</style></head>
        \\<body><h1>Zig Git Service</h1><p>Your minimal Git service is running!</p>
        \\<h2>API Endpoints:</h2><ul>
        \\<li><code>GET /api/repos</code> - List all repositories</li>
        \\<li><code>POST /api/repos</code> - Create a new repository</li>
        \\<li><code>GET /api/repo/{name}</code> - Get repository info</li>
        \\</ul><h2>Example Usage:</h2><pre>
        \\# Create a new repository
        \\curl -X POST -H "Content-Type: application/json" -d '{"name":"example"}' http://localhost:8080/api/repos
        \\# List all repositories
        \\curl http://localhost:8080/api/repos
        \\</pre></body></html>
    ;
    _ = try conn.stream.write(html);
}

fn sendJsonResponse(conn: Connection, status: u16, json: []const u8) !void {
    var header: [256]u8 = undefined;
    const status_msg = switch (status) {
        200 => "OK",
        201 => "Created",
        400 => "Bad Request",
        404 => "Not Found",
        405 => "Method Not Allowed",
        500 => "Internal Server Error",
        else => "Unknown",
    };
    const header_str = try std.fmt.bufPrint(
        &header,
        "HTTP/1.1 {d} {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
        .{ status, status_msg, json.len },
    );
    _ = try conn.stream.write(header_str);
    _ = try conn.stream.write(json);
}

fn sendError(conn: Connection, status: u16, msg: []const u8) void {
    const json = std.fmt.allocPrint(std.heap.page_allocator, "{{\"error\":\"{s}\"}}", .{msg}) catch return;
    defer std.heap.page_allocator.free(json);
    sendJsonResponse(conn, status, json) catch return;
}
