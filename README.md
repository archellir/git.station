# Git station

A high-performance, extremely lightweight Git service built with Zig and SvelteKit.

## Features

- Create and manage Git repositories
- Web-based repository browsing
- CI/CD pipeline integration
- Optimized for performance and minimal resource usage

## Project Structure

```
git-service/
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
```

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

## Development

The backend server will be available at http://localhost:8080
The frontend development server will be available at http://localhost:5173

## License

MIT