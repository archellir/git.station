# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

### Git Commit Guidelines

**Rules**:
- NEVER add co-authors, "Generated with" tags, or metadata
- Focus on what changed and why, not how or who
- Use present tense ("add feature" not "added feature")
- Use lowercase for description
- No period at the end of description
- Keep commit message under 50 characters
- Try to avoid adding commit message unless absolutely necessary
- Keep description line under 72 characters

Follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

**Format**: `type(scope): description`

**Required components**:
- `type`: feat, fix, docs, style, refactor, test, chore
- `scope`: component/area affected (api, auth, gitops, k8s, ui, etc.)
- `description`: concise description of changes

**Commit size limits**:
- **Maximum 1-2 files per commit** (can be more only if absolutely necessary)
- One logical change per commit, commit must be granular
- Separate unrelated changes into different commits

**Examples**:
- `feat(gitops): add repository management service`
- `fix(auth): resolve PASETO token expiration issue`
- `docs(readme): update installation instructions`
- `refactor(api): extract common response handlers`

### Always Use Standard CLI Tools for Initialization
- **Go Backend**: Use `go mod init` to initialize Go modules
- **React Frontend**: Use `npm create vite@latest my-app -- --template react`
- **Alpine.js**: `pnpm init vite@latest my-alpine-app -- --template vanilla-ts`
- ALWAYS use `pnpm` instead of `npm`
- ALWAYS use Typescript instead of Javascript
- **Svelte**: `npx sv create my-app`
- **Rust**: `cargo new`, `cargo add`
- **Zig**: `zig init`
- **Never manually create package.json or go.mod files**
- **ALWAYS use official scaffolding tools**

# Using Gemini CLI for Large Codebase Analysis

When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive
context window. Use `gemini -p` to leverage Google Gemini's large context capacity.

## File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the
  gemini command:

### Examples:

**Single file analysis:**
```sh
gemini -p "@src/main.py Explain this file's purpose and structure"

#Multiple files:
gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"

#Entire directory:
gemini -p "@src/ Summarize the architecture of this codebase"

#Multiple directories:
gemini -p "@src/ @tests/ Analyze test coverage for the source code"

#Current directory and subdirectories:
gemini -p "@./ Give me an overview of this entire project"

# Or use --all_files flag:
gemini --all_files -p "Analyze the project structure and dependencies"

#Implementation Verification Examples

#Check if a feature is implemented:
gemini -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"

#Verify authentication implementation:
gemini -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"

#Check for specific patterns:
gemini -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"

#Verify error handling:
gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"

#Check for rate limiting:
gemini -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"

#Verify caching strategy:
gemini -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"

#Check for specific security measures:
gemini -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"

#Verify test coverage for features:
gemini -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"
```

When to Use Gemini CLI

Use gemini -p when:
- Analyzing entire codebases or large directories
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase

Important Notes
- Paths in @ syntax are relative to your current working directory when invoking gemini
- The CLI will include file contents directly in the context
- No need for --yolo flag for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results

## Project Overview

Git Station is a lightweight, high-performance Git hosting service built with Zig (backend) and designed to serve as a self-hosted alternative to GitHub/GitLab. The backend is complete and functional, but the frontend (SvelteKit) is not yet implemented.

## Development Commands

### Building and Running
```bash
cd backend
zig build                    # Build the application
zig build run               # Build and run the server
```

### Testing
Use the comprehensive test runner script:
```bash
cd backend
sh run-tests.sh             # Run all tests in Docker (default)
sh run-tests.sh --local     # Run all tests locally
sh run-tests.sh --git       # Run only Git-related tests
sh run-tests.sh --db        # Run only database tests
sh run-tests.sh --auth      # Run only authentication tests
sh run-tests.sh --unit      # Run only unit tests
```

Individual test commands (local):
```bash
# macOS
zig test src/git_test.zig -lc -lgit2 -I/opt/homebrew/include -L/opt/homebrew/lib
zig test src/database_test.zig -lc -lsqlite3
zig test src/auth_test.zig -lc
zig test src/main_test.zig -lc -lsqlite3 -lgit2

# Linux/Docker
zig test src/git_test.zig -lc -lgit2 -I/usr/include -L/usr/lib/x86_64-linux-gnu
```

### Docker Development
```bash
docker-compose build backend
docker-compose run backend zig build run
```

## Architecture

### Core Modules
- **main.zig**: HTTP server with comprehensive REST API routing
- **git.zig**: Git operations wrapper around libgit2 
- **database.zig**: SQLite-based data persistence (Issues, Pull Requests)
- **auth.zig**: Simple session-based authentication system

### Key Dependencies
- **libgit2**: Git repository operations (clone, branch, commit, merge)
- **SQLite3**: Data storage for metadata (issues, PRs, sessions)
- **Standard Zig HTTP**: Custom HTTP server implementation

### API Structure
The server provides a comprehensive REST API:
- Repository management: `/api/repos`, `/api/repo/{name}`
- Branch operations: `/api/repo/{name}/branches` 
- File browsing: `/api/repo/{name}/tree/{branch}/{path}`, `/api/repo/{name}/blob/{branch}/{path}`
- Commit history: `/api/repo/{name}/commits/{branch}`
- Pull requests: `/api/repo/{name}/pulls` (full CRUD + merge/close)
- Issues: `/api/repo/{name}/issues` (full CRUD)

### Data Flow
1. HTTP requests hit main.zig routing logic
2. Authentication checked via auth.zig session tokens  
3. Git operations delegated to git.zig (libgit2 wrapper)
4. Metadata operations use database.zig (SQLite)
5. JSON responses returned to client

### Repository Storage
- Physical repos stored in `./repositories/` directory
- Database metadata in `git_station.db`
- In-memory session management (non-persistent)

## Key Implementation Notes

### Authentication
Currently uses hardcoded admin credentials (`admin`/`password123`) with in-memory sessions. Sessions are not persistent across server restarts.

### Git Operations
All Git functionality wraps libgit2 C library calls. Repository paths are resolved relative to `REPO_PATH` constant (`./repositories`).

### Error Handling
Each module defines custom error types (GitError, DatabaseError, etc.) with descriptive error propagation through the HTTP layer.

### Testing Strategy
Comprehensive test suite covers:
- Unit tests for each module
- Integration tests for HTTP endpoints  
- Git repository manipulation tests
- Database persistence tests
- Cross-platform support (macOS/Linux)

## Missing Components

The project is missing its frontend - there's no `frontend/` directory. The backend can serve static files and would be capable of serving a SPA, but this needs to be implemented in the HTTP routing logic.

## Development Environment

### macOS Requirements
```bash
brew install zig libgit2 sqlite3
```

### Linux Requirements  
```bash
apt-get install zig libgit2-dev libsqlite3-dev
```

The server runs on `127.0.0.1:8080` and expects repositories in a local `repositories/` directory.

## Git Station Completion Plan - Cyberpunk UI with Tailwind

### Phase 1: Frontend Setup & Architecture
**Goal**: Create SvelteKit 5 foundation with Tailwind-powered cyberpunk theme

**Tasks**:
1. **Initialize SvelteKit Project** (following CLAUDE.md guidelines)
   - Use `npx sv create frontend` with TypeScript
   - Set up `pnpm` as package manager
   - Install and configure Tailwind CSS with custom cyberpunk theme

2. **Cyberpunk Design System**
   - Configure Tailwind with cyberpunk color palette (neon greens, purples, dark backgrounds)
   - Create custom component classes for cyberpunk elements
   - Set up terminal-inspired typography and spacing
   - Design reusable Tailwind component patterns

### Phase 2: Core UI Implementation
**Goal**: Build main views using Tailwind utility classes

**Tasks**:
3. **Repository Dashboard**
   - Grid layout with cyberpunk-styled cards using Tailwind
   - Search with neon focus states and glitch effects
   - Create repo modal with dark glass morphism

4. **Repository Browser**
   - File tree with Tailwind hover states and neon accents
   - Code viewer with dark theme and syntax highlighting
   - Commit timeline with gradient borders and glow effects
   - Branch switcher with animated cyberpunk transitions

### Phase 3: Advanced Features
**Goal**: PR/Issue management with consistent Tailwind styling

**Tasks**:
5. **Pull Request & Issue Management**
   - List views with Tailwind status badges and neon indicators
   - Forms with cyberpunk input styling and validation states
   - Markdown preview with dark Tailwind prose

6. **Authentication**
   - Login form with cyberpunk Tailwind components
   - Session management UI
   - Protected route styling

### Phase 4: Backend Integration
**Goal**: Connect to Zig backend with SPA serving

**Tasks**:
7. **Static File Serving**
   - Modify Zig backend for SvelteKit build output
   - SPA routing fallback implementation

8. **API Integration**  
   - HTTP client with Tailwind loading/error states
   - Cyberpunk error pages and loading spinners

### Phase 5: Polish & Deployment
**Goal**: Production-ready with responsive Tailwind design

**Tasks**:
9. **Responsive & Accessible**
   - Mobile-first Tailwind breakpoints
   - Dark mode optimization
   - Accessibility with Tailwind utilities

10. **Build Pipeline**
    - Tailwind production optimization
    - Docker integration
    - Single-container deployment

### Technical Stack
- **Frontend**: Svelte 5 + SvelteKit + TypeScript + Tailwind CSS
- **Package Manager**: pnpm
- **Styling**: Tailwind with custom cyberpunk theme configuration
- **Backend**: Existing Zig API
- **Deployment**: Docker + static serving

This approach uses Tailwind's utility-first methodology to rapidly build the cyberpunk aesthetic while maintaining consistency and performance.