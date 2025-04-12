# Git station

A high-performance, extremely lightweight Git service built with Zig and SvelteKit.

## Features

- Create and manage Git repositories
- Web-based repository browsing
- CI/CD pipeline integration
- Optimized for performance and minimal resource usage

## Project Structure

```
git.station/
├── backend/     # Zig backend
├── frontend/    # SvelteKit frontend
└── scripts/     # Helper scripts
```

## Getting Started

### Prerequisites

- [Zig](https://ziglang.org/) (0.14.0 or later)
- [Node.js](https://nodejs.org/) (18 or later)
- [libgit2](https://libgit2.org/) development libraries
- [SQLite3](https://www.sqlite.org/) development libraries

### Backend Setup

```bash
cd backend
zig build
zig build run
# zig build && zig build run
```

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

## Testing

Git Station includes a comprehensive test suite for the backend components. Tests can be run either locally or in Docker.

### Running Tests

The `run-tests.sh` script in the `backend` directory provides various options for running tests:

```bash
cd backend
sh run-tests.sh [options]
```

#### Test Options

- `--all`: Run all tests (default)
- `--git`: Run only Git-related tests
- `--db`: Run only database tests
- `--auth`: Run only authentication tests
- `--unit`: Run only unit tests
- `--local`: Run tests locally instead of in Docker
- `--help`: Show help message

### Examples

Run all tests in Docker (requires Docker and docker-compose):
```bash
sh run-tests.sh
```

Run only Git tests locally:
```bash
sh run-tests.sh --git --local
```

Run database tests locally:
```bash
sh run-tests.sh --db --local
```

### Testing Environment Requirements

#### Local Testing
For local testing, you need:
- Zig compiler (0.14.0 or later)
- libgit2 development libraries
- SQLite3 development libraries

On macOS, you can install these with Homebrew:
```bash
brew install zig libgit2 sqlite3
```

On Linux (Debian/Ubuntu):
```bash
apt-get install zig libgit2-dev libsqlite3-dev
```

#### Docker Testing
For Docker-based testing, you need:
- Docker
- docker-compose

The Docker setup handles all dependencies automatically.

## Development

<img width="863" alt="Screenshot 2025-03-07 at 03 14 42" src="https://github.com/user-attachments/assets/6ec8e2a7-0aa7-4b1c-aec1-71148c60a33e" />

- The backend server will be available at http://localhost:8080
- The frontend development server will be available at http://localhost:5173

## License

MIT
