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

- [Zig](https://ziglang.org/) (0.11.0 or later)
- [Node.js](https://nodejs.org/) (18 or later)
- [libgit2](https://libgit2.org/) development libraries

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

## Development

<img width="863" alt="Screenshot 2025-03-07 at 03 14 42" src="https://github.com/user-attachments/assets/6ec8e2a7-0aa7-4b1c-aec1-71148c60a33e" />

- The backend server will be available at http://localhost:8080
- The frontend development server will be available at http://localhost:5173

## License

MIT
