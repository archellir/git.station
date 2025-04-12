const std = @import("std");
const git = @import("git.zig");
const auth = @import("auth.zig");
const db = @import("database.zig");

const REPO_PATH = "./repositories";
const SERVER_ADDRESS = "127.0.0.1:8080";

const Connection = struct {
    stream: std.net.Stream,
    address: std.net.Address,
};

pub fn main() !void {
    // Initialize the underlying libs
    git.init();
    defer git.deinit();

    auth.init();
    defer auth.deinit();

    try db.init();
    defer db.deinit();

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

    var buffer: [8192]u8 = undefined; // Increased buffer size for larger requests
    const bytes_read = conn.stream.read(&buffer) catch |err| {
        std.debug.print("Failed to read request: {}\n", .{err});
        return;
    };

    if (bytes_read == 0) return;

    const request = buffer[0..bytes_read];
    const method = parseMethod(request) orelse return sendError(conn, 400, "Invalid request method");
    const path = parsePath(request) orelse return sendError(conn, 400, "Invalid request path");

    // Extract auth token from cookies if present
    const auth_token = parseCookie(request, "session") orelse "";
    const is_authenticated = auth_token.len > 0 and auth.validateSession(auth_token);

    // Routes that don't require authentication
    if (std.mem.eql(u8, path, "/api/login") and std.mem.eql(u8, method, "POST")) {
        handleLogin(conn, request, allocator) catch |err| {
            std.debug.print("Login failed: {}\n", .{err});
            return sendError(conn, 401, "Authentication failed");
        };
        return;
    } else if (std.mem.eql(u8, method, "GET") and !std.mem.startsWith(u8, path, "/api/")) {
        serveWelcomePage(conn) catch return sendError(conn, 500, "Failed to serve welcome page");
        return;
    }

    // All API routes (except login) require authentication
    if (!is_authenticated and std.mem.startsWith(u8, path, "/api/")) {
        return sendError(conn, 401, "Authentication required");
    }

    // Authenticated routes
    if (std.mem.eql(u8, method, "GET")) {
        if (std.mem.eql(u8, path, "/api/repos")) {
            handleListRepos(conn, allocator) catch return sendError(conn, 500, "Failed to list repos");
        } else if (std.mem.startsWith(u8, path, "/api/repo/")) {
            if (std.mem.endsWith(u8, path, "/branches")) {
                const repo_name = path["/api/repo/".len .. path.len - "/branches".len];
                handleListBranches(conn, allocator, repo_name) catch return sendError(conn, 500, "Failed to list branches");
            } else if (std.mem.indexOf(u8, path, "/commits/") != null) {
                const repo_path_end = std.mem.indexOf(u8, path, "/commits/") orelse return sendError(conn, 400, "Invalid path");
                const _repo_name = path["/api/repo/".len..repo_path_end];
                const branch_name = path[repo_path_end + "/commits/".len ..];
                handleListCommits(conn, allocator, _repo_name, branch_name) catch return sendError(conn, 500, "Failed to list commits");
            } else if (std.mem.indexOf(u8, path, "/tree/") != null) {
                const repo_path_end = std.mem.indexOf(u8, path, "/tree/") orelse return sendError(conn, 400, "Invalid path");
                const _repo_name = path["/api/repo/".len..repo_path_end];
                const remaining_path = path[repo_path_end + "/tree/".len ..];

                const branch_path_end = std.mem.indexOf(u8, remaining_path, "/");
                if (branch_path_end == null) {
                    // List root directory of branch
                    const branch_name = remaining_path;
                    handleListDirectory(conn, allocator, _repo_name, branch_name, "") catch return sendError(conn, 500, "Failed to list directory");
                } else {
                    // List specified directory
                    const branch_name = remaining_path[0..branch_path_end.?];
                    const dir_path = remaining_path[branch_path_end.? + 1 ..];
                    handleListDirectory(conn, allocator, _repo_name, branch_name, dir_path) catch return sendError(conn, 500, "Failed to list directory");
                }
            } else if (std.mem.indexOf(u8, path, "/blob/") != null) {
                const repo_path_end = std.mem.indexOf(u8, path, "/blob/") orelse return sendError(conn, 400, "Invalid path");
                const _repo_name = path["/api/repo/".len..repo_path_end];
                const remaining_path = path[repo_path_end + "/blob/".len ..];

                const branch_path_end = std.mem.indexOf(u8, remaining_path, "/") orelse return sendError(conn, 400, "Invalid path");
                const branch_name = remaining_path[0..branch_path_end];
                const file_path = remaining_path[branch_path_end + 1 ..];

                handleGetFile(conn, allocator, _repo_name, branch_name, file_path) catch return sendError(conn, 500, "Failed to get file");
            } else if (std.mem.endsWith(u8, path, "/issues")) {
                const _repo_name = path["/api/repo/".len .. path.len - "/issues".len];
                handleListIssues(conn, allocator, _repo_name) catch return sendError(conn, 500, "Failed to list issues");
            } else if (std.mem.endsWith(u8, path, "/pulls")) {
                const _repo_name = path["/api/repo/".len .. path.len - "/pulls".len];
                handleListPullRequests(conn, allocator, _repo_name) catch return sendError(conn, 500, "Failed to list pull requests");
            } else if (std.mem.indexOf(u8, path, "/issues/") != null) {
                const repo_path_end = std.mem.indexOf(u8, path, "/issues/") orelse return sendError(conn, 400, "Invalid path");
                const issue_id_str = path[repo_path_end + "/issues/".len ..];
                const issue_id = std.fmt.parseInt(usize, issue_id_str, 10) catch return sendError(conn, 400, "Invalid issue ID");

                handleGetIssue(conn, allocator, issue_id) catch return sendError(conn, 500, "Failed to get issue");
            } else if (std.mem.indexOf(u8, path, "/pulls/") != null) {
                const repo_path_end = std.mem.indexOf(u8, path, "/pulls/") orelse return sendError(conn, 400, "Invalid path");
                const pr_id_str = path[repo_path_end + "/pulls/".len ..];
                const pr_id = std.fmt.parseInt(usize, pr_id_str, 10) catch return sendError(conn, 400, "Invalid pull request ID");

                handleGetPullRequest(conn, allocator, pr_id) catch return sendError(conn, 500, "Failed to get pull request");
            } else {
                const _repo_name = path["/api/repo/".len..];
                handleGetRepo(conn, allocator, _repo_name) catch return sendError(conn, 500, "Failed to get repo");
            }
        } else {
            sendError(conn, 404, "Not found");
        }
    } else if (std.mem.eql(u8, method, "POST")) {
        if (std.mem.eql(u8, path, "/api/repos")) {
            const repo_name = parseRepoNameFromBody(request, allocator) catch return sendError(conn, 400, "Invalid repo name in request body");
            defer allocator.free(repo_name);
            handleCreateRepo(conn, allocator, repo_name) catch return sendError(conn, 500, "Failed to create repo");
        } else if (std.mem.startsWith(u8, path, "/api/repo/") and std.mem.endsWith(u8, path, "/branches")) {
            const repo_name = path["/api/repo/".len .. path.len - "/branches".len];
            const branch_name = parseBranchNameFromBody(request, allocator) catch return sendError(conn, 400, "Invalid branch name in request body");
            defer allocator.free(branch_name);
            handleCreateBranch(conn, allocator, repo_name, branch_name) catch return sendError(conn, 500, "Failed to create branch");
        } else if (std.mem.startsWith(u8, path, "/api/repo/") and std.mem.endsWith(u8, path, "/issues")) {
            const repo_name = path["/api/repo/".len .. path.len - "/issues".len];
            handleCreateIssue(conn, request, allocator, repo_name) catch return sendError(conn, 500, "Failed to create issue");
        } else if (std.mem.startsWith(u8, path, "/api/repo/") and std.mem.endsWith(u8, path, "/pulls")) {
            const repo_name = path["/api/repo/".len .. path.len - "/pulls".len];
            handleCreatePullRequest(conn, request, allocator, repo_name) catch return sendError(conn, 500, "Failed to create pull request");
        } else {
            sendError(conn, 404, "Not found");
        }
    } else if (std.mem.eql(u8, method, "PATCH") or std.mem.eql(u8, method, "PUT")) {
        if (std.mem.indexOf(u8, path, "/issues/") != null) {
            const repo_path_end = std.mem.indexOf(u8, path, "/issues/") orelse return sendError(conn, 400, "Invalid path");
            const issue_id_str = path[repo_path_end + "/issues/".len ..];
            const issue_id = std.fmt.parseInt(usize, issue_id_str, 10) catch return sendError(conn, 400, "Invalid issue ID");

            handleUpdateIssue(conn, request, allocator, issue_id) catch return sendError(conn, 500, "Failed to update issue");
        } else if (std.mem.indexOf(u8, path, "/pulls/") != null) {
            const repo_path_end = std.mem.indexOf(u8, path, "/pulls/") orelse return sendError(conn, 400, "Invalid path");
            const pr_id_str = path[repo_path_end + "/pulls/".len ..];
            const pr_id = std.fmt.parseInt(usize, pr_id_str, 10) catch return sendError(conn, 400, "Invalid pull request ID");

            if (std.mem.endsWith(u8, path, "/merge")) {
                handleMergePullRequest(conn, allocator, pr_id) catch return sendError(conn, 500, "Failed to merge pull request");
            } else {
                handleUpdatePullRequest(conn, request, allocator, pr_id) catch return sendError(conn, 500, "Failed to update pull request");
            }
        } else {
            sendError(conn, 404, "Not found");
        }
    } else {
        sendError(conn, 405, "Method not allowed");
    }
}

// Parse helper functions
fn parseMethod(request: []const u8) ?[]const u8 {
    if (request.len < 4) return null;
    return request[0 .. std.mem.indexOf(u8, request, " ") orelse return null];
}

fn parsePath(request: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, request, " ") orelse return null;
    const end = std.mem.indexOfPos(u8, request, start + 1, " ") orelse return null;
    return request[start + 1 .. end];
}

fn parseCookie(request: []const u8, name: []const u8) ?[]const u8 {
    const cookie_header_prefix = "Cookie: ";
    var lines = std.mem.split(u8, request, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, cookie_header_prefix)) {
            const cookies = line[cookie_header_prefix.len..];
            var cookie_pairs = std.mem.split(u8, cookies, "; ");
            while (cookie_pairs.next()) |pair| {
                const eq_pos = std.mem.indexOf(u8, pair, "=") orelse continue;
                const cookie_name = pair[0..eq_pos];
                const cookie_value = pair[eq_pos + 1 ..];

                if (std.mem.eql(u8, cookie_name, name)) {
                    return cookie_value;
                }
            }
        }
    }
    return null;
}

fn parseRepoNameFromBody(request: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];
    const name_start = std.mem.indexOf(u8, body, "\"name\":") orelse return error.NoName;
    const quote_start = std.mem.indexOfPos(u8, body, name_start + "\"name\":".len, "\"") orelse return error.InvalidJson;
    const quote_end = std.mem.indexOfPos(u8, body, quote_start + 1, "\"") orelse return error.InvalidJson;
    return try allocator.dupe(u8, body[quote_start + 1 .. quote_end]);
}

fn parseBranchNameFromBody(request: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];
    const name_start = std.mem.indexOf(u8, body, "\"name\":") orelse return error.NoName;
    const quote_start = std.mem.indexOfPos(u8, body, name_start + "\"name\":".len, "\"") orelse return error.InvalidJson;
    const quote_end = std.mem.indexOfPos(u8, body, quote_start + 1, "\"") orelse return error.InvalidJson;
    return try allocator.dupe(u8, body[quote_start + 1 .. quote_end]);
}

fn parseJsonString(body: []const u8, key: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    const key_str = try std.fmt.allocPrint(allocator, "\"{s}\":", .{key});
    defer allocator.free(key_str);

    const key_start = std.mem.indexOf(u8, body, key_str) orelse return null;
    const quote_start = std.mem.indexOfPos(u8, body, key_start + key_str.len, "\"") orelse return error.InvalidJson;
    const quote_end = std.mem.indexOfPos(u8, body, quote_start + 1, "\"") orelse return error.InvalidJson;
    return try allocator.dupe(u8, body[quote_start + 1 .. quote_end]);
}

// Handler implementations
fn handleLogin(conn: Connection, request: []const u8, allocator: std.mem.Allocator) !void {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];

    const username = parseJsonString(body, "username", allocator) catch return error.InvalidJson;
    defer if (username != null) allocator.free(username.?);

    const password = parseJsonString(body, "password", allocator) catch return error.InvalidJson;
    defer if (password != null) allocator.free(password.?);

    if (username == null or password == null) {
        return error.InvalidCredentials;
    }

    if (!auth.authenticate(username.?, password.?)) {
        return error.InvalidCredentials;
    }

    const token = try auth.createSession(allocator);
    defer allocator.free(token);

    const cookie = try std.fmt.allocPrint(allocator, "session={s}; Path=/; HttpOnly", .{token});
    defer allocator.free(cookie);

    const json = try std.fmt.allocPrint(allocator, "{{\"status\":\"success\",\"message\":\"Logged in successfully\"}}", .{});
    defer allocator.free(json);

    var header: [512]u8 = undefined;
    const header_str = try std.fmt.bufPrint(
        &header,
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nSet-Cookie: {s}\r\nConnection: close\r\n\r\n",
        .{ json.len, cookie },
    );
    _ = try conn.stream.write(header_str);
    _ = try conn.stream.write(json);
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

fn handleListBranches(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    const repo = try git.openRepository(repo_path, allocator);
    defer git.freeRepository(repo);

    const branches = try git.listBranches(repo, allocator);
    defer {
        for (branches) |branch| allocator.free(branch);
        allocator.free(branches);
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.writer().writeAll("{\"branches\":[");
    for (branches, 0..) |branch, i| {
        try json.writer().print("\"{s}\"", .{branch});
        if (i < branches.len - 1) try json.writer().writeAll(",");
    }
    try json.writer().writeAll("]}");

    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleCreateBranch(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8, branch_name: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    const repo = try git.openRepository(repo_path, allocator);
    defer git.freeRepository(repo);

    try git.createBranch(repo, branch_name, allocator);

    const json = try std.fmt.allocPrint(allocator, "{{\"status\":\"created\",\"name\":\"{s}\"}}", .{branch_name});
    defer allocator.free(json);
    try sendJsonResponse(conn, 201, json);
}

fn handleListCommits(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8, branch_name: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    const repo = try git.openRepository(repo_path, allocator);
    defer git.freeRepository(repo);

    const commits = try git.getCommits(repo, branch_name, allocator, 50); // Limit to 50 commits
    defer {
        for (commits) |commit| {
            allocator.free(commit.message);
            allocator.free(commit.author);
        }
        allocator.free(commits);
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.writer().writeAll("{\"commits\":[");
    for (commits, 0..) |commit, i| {
        // Get a safe version of the message for JSON
        var safe_message = std.ArrayList(u8).init(allocator);
        defer safe_message.deinit();
        for (commit.message) |c| {
            if (c == '\n' or c == '\r') {
                try safe_message.writer().writeByte(' ');
            } else if (c == '"' or c == '\\') {
                try safe_message.writer().writeByte('\\');
                try safe_message.writer().writeByte(c);
            } else {
                try safe_message.writer().writeByte(c);
            }
        }

        try json.writer().print("{{\"id\":\"{s}\",\"message\":\"{s}\",\"author\":\"{s}\",\"timestamp\":{d}}}", .{ commit.id, safe_message.items, commit.author, commit.timestamp });
        if (i < commits.len - 1) try json.writer().writeAll(",");
    }
    try json.writer().writeAll("]}");

    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleListDirectory(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8, branch_name: []const u8, dir_path: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    const repo = try git.openRepository(repo_path, allocator);
    defer git.freeRepository(repo);

    const entries = try git.listDirectory(repo, branch_name, dir_path, allocator);
    defer {
        for (entries) |entry| allocator.free(entry.name);
        allocator.free(entries);
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.writer().writeAll("{\"entries\":[");
    for (entries, 0..) |entry, i| {
        try json.writer().print("{{\"name\":\"{s}\",\"type\":\"{s}\"}}", .{ entry.name, if (entry.is_dir) "dir" else "file" });
        if (i < entries.len - 1) try json.writer().writeAll(",");
    }
    try json.writer().writeAll("]}");

    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleGetFile(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8, branch_name: []const u8, file_path: []const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const repo_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ REPO_PATH, repo_name });

    const repo = try git.openRepository(repo_path, allocator);
    defer git.freeRepository(repo);

    const content = try git.getFileContent(repo, branch_name, file_path, allocator);
    defer allocator.free(content);

    // Turn binary content into base64 if it's binary
    var is_binary = false;
    for (content) |c| {
        if (c == 0 or (c < 32 and c != '\n' and c != '\r' and c != '\t')) {
            is_binary = true;
            break;
        }
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();

    if (is_binary) {
        // Base64 encode binary content
        const base64_len = (content.len + 2) / 3 * 4;
        const base64 = try allocator.alloc(u8, base64_len);
        defer allocator.free(base64);

        _ = std.base64.standard.Encoder.encode(base64, content);

        try json.writer().print("{{\"path\":\"{s}\",\"content\":\"{s}\",\"encoding\":\"base64\"}}", .{ file_path, base64 });
    } else {
        // JSON escape text content
        var safe_content = std.ArrayList(u8).init(allocator);
        defer safe_content.deinit();

        for (content) |c| {
            if (c == '"' or c == '\\') {
                try safe_content.writer().writeByte('\\');
                try safe_content.writer().writeByte(c);
            } else if (c == '\n') {
                try safe_content.writer().writeAll("\\n");
            } else if (c == '\r') {
                try safe_content.writer().writeAll("\\r");
            } else if (c == '\t') {
                try safe_content.writer().writeAll("\\t");
            } else {
                try safe_content.writer().writeByte(c);
            }
        }

        try json.writer().print("{{\"path\":\"{s}\",\"content\":\"{s}\",\"encoding\":\"utf8\"}}", .{ file_path, safe_content.items });
    }

    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleCreateIssue(conn: Connection, request: []const u8, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];

    const title = parseJsonString(body, "title", allocator) catch return error.InvalidJson;
    defer if (title != null) allocator.free(title.?);

    const content = parseJsonString(body, "body", allocator) catch return error.InvalidJson;
    defer if (content != null) allocator.free(content.?);

    if (title == null or content == null) {
        return error.InvalidIssueData;
    }

    const issue_id = try db.createIssue(repo_name, title.?, content.?, allocator);

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"status\":\"created\"}}", .{issue_id});
    defer allocator.free(json);
    try sendJsonResponse(conn, 201, json);
}

fn handleGetIssue(conn: Connection, allocator: std.mem.Allocator, issue_id: usize) !void {
    const issue = try db.getIssue(issue_id, allocator);
    defer {
        allocator.free(issue.repo_name);
        allocator.free(issue.title);
        allocator.free(issue.body);
        allocator.free(issue.state);
    }

    // JSON escape body
    var safe_body = std.ArrayList(u8).init(allocator);
    defer safe_body.deinit();

    for (issue.body) |c| {
        if (c == '"' or c == '\\') {
            try safe_body.writer().writeByte('\\');
            try safe_body.writer().writeByte(c);
        } else if (c == '\n') {
            try safe_body.writer().writeAll("\\n");
        } else if (c == '\r') {
            try safe_body.writer().writeAll("\\r");
        } else if (c == '\t') {
            try safe_body.writer().writeAll("\\t");
        } else {
            try safe_body.writer().writeByte(c);
        }
    }

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"repo_name\":\"{s}\",\"title\":\"{s}\",\"body\":\"{s}\",\"state\":\"{s}\",\"created_at\":{d},\"updated_at\":{d}}}", .{ issue.id, issue.repo_name, issue.title, safe_body.items, issue.state, issue.created_at, issue.updated_at });
    defer allocator.free(json);

    try sendJsonResponse(conn, 200, json);
}

fn handleListIssues(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    const issues = try db.listIssues(repo_name, allocator);
    defer {
        for (issues) |issue| {
            allocator.free(issue.repo_name);
            allocator.free(issue.title);
            allocator.free(issue.body);
            allocator.free(issue.state);
        }
        allocator.free(issues);
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.writer().writeAll("{\"issues\":[");

    for (issues, 0..) |issue, i| {
        // JSON escape title
        var safe_title = std.ArrayList(u8).init(allocator);
        defer safe_title.deinit();

        for (issue.title) |c| {
            if (c == '"' or c == '\\') {
                try safe_title.writer().writeByte('\\');
                try safe_title.writer().writeByte(c);
            } else {
                try safe_title.writer().writeByte(c);
            }
        }

        try json.writer().print("{{\"id\":{d},\"title\":\"{s}\",\"state\":\"{s}\",\"created_at\":{d},\"updated_at\":{d}}}", .{ issue.id, safe_title.items, issue.state, issue.created_at, issue.updated_at });

        if (i < issues.len - 1) {
            try json.writer().writeAll(",");
        }
    }

    try json.writer().writeAll("]}");
    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleUpdateIssue(conn: Connection, request: []const u8, allocator: std.mem.Allocator, issue_id: usize) !void {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];

    const title = try parseJsonString(body, "title", allocator);
    defer if (title != null) allocator.free(title.?);

    const content = try parseJsonString(body, "body", allocator);
    defer if (content != null) allocator.free(content.?);

    const state = try parseJsonString(body, "state", allocator);
    defer if (state != null) allocator.free(state.?);

    try db.updateIssue(issue_id, title, content, state, allocator);

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"status\":\"updated\"}}", .{issue_id});
    defer allocator.free(json);
    try sendJsonResponse(conn, 200, json);
}

fn handleCreatePullRequest(conn: Connection, request: []const u8, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];

    const title = parseJsonString(body, "title", allocator) catch return error.InvalidJson;
    defer if (title != null) allocator.free(title.?);

    const content = parseJsonString(body, "body", allocator) catch return error.InvalidJson;
    defer if (content != null) allocator.free(content.?);

    const source_branch = parseJsonString(body, "source_branch", allocator) catch return error.InvalidJson;
    defer if (source_branch != null) allocator.free(source_branch.?);

    const target_branch = parseJsonString(body, "target_branch", allocator) catch return error.InvalidJson;
    defer if (target_branch != null) allocator.free(target_branch.?);

    if (title == null or content == null or source_branch == null or target_branch == null) {
        return error.InvalidPullRequestData;
    }

    const pr_id = try db.createPullRequest(repo_name, title.?, content.?, source_branch.?, target_branch.?, allocator);

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"status\":\"created\"}}", .{pr_id});
    defer allocator.free(json);
    try sendJsonResponse(conn, 201, json);
}

fn handleGetPullRequest(conn: Connection, allocator: std.mem.Allocator, pr_id: usize) !void {
    const pr = try db.getPullRequest(pr_id, allocator);
    defer {
        allocator.free(pr.repo_name);
        allocator.free(pr.title);
        allocator.free(pr.body);
        allocator.free(pr.source_branch);
        allocator.free(pr.target_branch);
        allocator.free(pr.state);
    }

    // JSON escape body
    var safe_body = std.ArrayList(u8).init(allocator);
    defer safe_body.deinit();

    for (pr.body) |c| {
        if (c == '"' or c == '\\') {
            try safe_body.writer().writeByte('\\');
            try safe_body.writer().writeByte(c);
        } else if (c == '\n') {
            try safe_body.writer().writeAll("\\n");
        } else if (c == '\r') {
            try safe_body.writer().writeAll("\\r");
        } else if (c == '\t') {
            try safe_body.writer().writeAll("\\t");
        } else {
            try safe_body.writer().writeByte(c);
        }
    }

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"repo_name\":\"{s}\",\"title\":\"{s}\",\"body\":\"{s}\",\"source_branch\":\"{s}\",\"target_branch\":\"{s}\",\"state\":\"{s}\",\"created_at\":{d},\"updated_at\":{d}}}", .{ pr.id, pr.repo_name, pr.title, safe_body.items, pr.source_branch, pr.target_branch, pr.state, pr.created_at, pr.updated_at });
    defer allocator.free(json);

    try sendJsonResponse(conn, 200, json);
}

fn handleListPullRequests(conn: Connection, allocator: std.mem.Allocator, repo_name: []const u8) !void {
    const prs = try db.listPullRequests(repo_name, allocator);
    defer {
        for (prs) |pr| {
            allocator.free(pr.repo_name);
            allocator.free(pr.title);
            allocator.free(pr.body);
            allocator.free(pr.source_branch);
            allocator.free(pr.target_branch);
            allocator.free(pr.state);
        }
        allocator.free(prs);
    }

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.writer().writeAll("{\"pull_requests\":[");

    for (prs, 0..) |pr, i| {
        // JSON escape title
        var safe_title = std.ArrayList(u8).init(allocator);
        defer safe_title.deinit();

        for (pr.title) |c| {
            if (c == '"' or c == '\\') {
                try safe_title.writer().writeByte('\\');
                try safe_title.writer().writeByte(c);
            } else {
                try safe_title.writer().writeByte(c);
            }
        }

        try json.writer().print("{{\"id\":{d},\"title\":\"{s}\",\"source_branch\":\"{s}\",\"target_branch\":\"{s}\",\"state\":\"{s}\",\"created_at\":{d},\"updated_at\":{d}}}", .{ pr.id, safe_title.items, pr.source_branch, pr.target_branch, pr.state, pr.created_at, pr.updated_at });

        if (i < prs.len - 1) {
            try json.writer().writeAll(",");
        }
    }

    try json.writer().writeAll("]}");
    try sendJsonResponse(conn, 200, try json.toOwnedSlice());
}

fn handleUpdatePullRequest(conn: Connection, request: []const u8, allocator: std.mem.Allocator, pr_id: usize) !void {
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.NoBody;
    const body = request[body_start + 4 ..];

    const title = try parseJsonString(body, "title", allocator);
    defer if (title != null) allocator.free(title.?);

    const content = try parseJsonString(body, "body", allocator);
    defer if (content != null) allocator.free(content.?);

    const state = try parseJsonString(body, "state", allocator);
    defer if (state != null) allocator.free(state.?);

    try db.updatePullRequest(pr_id, title, content, state, allocator);

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"status\":\"updated\"}}", .{pr_id});
    defer allocator.free(json);
    try sendJsonResponse(conn, 200, json);
}

fn handleMergePullRequest(conn: Connection, allocator: std.mem.Allocator, pr_id: usize) !void {
    try db.mergePullRequest(pr_id, allocator);

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{d},\"status\":\"merged\"}}", .{pr_id});
    defer allocator.free(json);
    try sendJsonResponse(conn, 200, json);
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
        \\<body><h1>Git Service</h1><p>Your private GitHub service is running!</p>
        \\<h2>Features:</h2><ul>
        \\<li>Git repository management</li>
        \\<li>Issue tracking</li>
        \\<li>Pull requests</li>
        \\<li>Branch management</li>
        \\</ul>
        \\<p>Please log in using the frontend application to access all features.</p>
        \\<h2>API Endpoints:</h2><pre>
        \\# Authentication
        \\POST /api/login - Log in with username and password
        \\
        \\# Repositories
        \\GET /api/repos - List all repositories
        \\POST /api/repos - Create a new repository
        \\GET /api/repo/{name} - Get repository info
        \\
        \\# Branches
        \\GET /api/repo/{name}/branches - List all branches
        \\POST /api/repo/{name}/branches - Create a new branch
        \\
        \\# Commits
        \\GET /api/repo/{name}/commits/{branch} - List commits on branch
        \\
        \\# Files
        \\GET /api/repo/{name}/tree/{branch}/{path} - List files in directory
        \\GET /api/repo/{name}/blob/{branch}/{path} - Get file content
        \\
        \\# Issues
        \\GET /api/repo/{name}/issues - List issues
        \\POST /api/repo/{name}/issues - Create a new issue
        \\GET /api/repo/{name}/issues/{id} - Get issue details
        \\PUT /api/repo/{name}/issues/{id} - Update an issue
        \\
        \\# Pull Requests
        \\GET /api/repo/{name}/pulls - List pull requests
        \\POST /api/repo/{name}/pulls - Create a new pull request
        \\GET /api/repo/{name}/pulls/{id} - Get pull request details
        \\PUT /api/repo/{name}/pulls/{id} - Update a pull request
        \\PUT /api/repo/{name}/pulls/{id}/merge - Merge a pull request
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
        401 => "Unauthorized",
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
