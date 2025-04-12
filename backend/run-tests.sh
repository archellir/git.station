#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --all           Run all tests (default)"
    echo "  --git           Run only Git tests"
    echo "  --db            Run only database tests"
    echo "  --auth          Run only authentication tests"
    echo "  --unit          Run only unit tests"
    echo "  --local         Run tests locally instead of in Docker"
    echo "  --help          Show this help message"
    echo ""
    echo "Example: $0 --git"
}

# Default settings
TEST_COMMAND="test-all"
RUN_LOCALLY=false

# Parse command-line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --all)
            TEST_COMMAND="test-all"
            ;;
        --git)
            TEST_COMMAND="test-git"
            ;;
        --db)
            TEST_COMMAND="zig test src/database_test.zig -lc -lsqlite3"
            ;;
        --auth)
            TEST_COMMAND="zig test src/auth_test.zig -lc"
            ;;
        --unit)
            TEST_COMMAND="zig test src/main_test.zig -lc -lsqlite3 -lgit2 && zig test src/database_test.zig -lc -lsqlite3 && zig test src/auth_test.zig -lc && zig test src/git_test.zig -lc -lgit2 -I/opt/homebrew/include -L/opt/homebrew/lib"
            ;;
        --local)
            RUN_LOCALLY=true
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && [ "$RUN_LOCALLY" = false ]; then
    echo "Warning: docker-compose not found, falling back to local execution."
    RUN_LOCALLY=true
fi

# Check if Dockerfile and docker-compose.yml exist
if [ ! -f "Dockerfile" -a ! -f "backend/Dockerfile" ] || [ ! -f "docker-compose.yml" -a ! -f "../docker-compose.yml" ] && [ "$RUN_LOCALLY" = false ]; then
    echo "Warning: Dockerfile or docker-compose.yml not found, falling back to local execution."
    RUN_LOCALLY=true
fi

# Navigate to backend directory if needed (for local execution)
if [ "$RUN_LOCALLY" = true ]; then
    # Check if we're in the root directory
    if [ ! -d "backend/src" ] && [ ! -d "src" ]; then
        echo "Error: Cannot find backend/src or src directory."
        exit 1
    fi
    
    # Navigate to backend directory if we're in the root
    if [ ! -d "src" ] && [ -d "backend/src" ]; then
        cd backend
        echo "Changed directory to: $(pwd)"
    fi
fi

# Determine macOS vs Linux for local execution
if [ "$RUN_LOCALLY" = true ]; then
    # Determine platform and adjust commands
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        if [[ "$TEST_COMMAND" == "test-all" ]]; then
            TEST_COMMAND="zig test src/main_test.zig -lc -lsqlite3 -lgit2 && zig test src/database_test.zig -lc -lsqlite3 && zig test src/auth_test.zig -lc && zig test src/git_test.zig -lc -lgit2 -I/opt/homebrew/include -L/opt/homebrew/lib"
        elif [[ "$TEST_COMMAND" == "test-git" ]]; then
            TEST_COMMAND="zig test src/git_test.zig -lc -lgit2 -I/opt/homebrew/include -L/opt/homebrew/lib"
        fi
    else
        # Linux
        if [[ "$TEST_COMMAND" == "test-all" ]]; then
            TEST_COMMAND="zig test src/main_test.zig -lc -lsqlite3 -lgit2 && zig test src/database_test.zig -lc -lsqlite3 && zig test src/auth_test.zig -lc && zig test src/git_test.zig -lc -lgit2 -I/usr/include -L/usr/lib/x86_64-linux-gnu"
        elif [[ "$TEST_COMMAND" == "test-git" ]]; then
            TEST_COMMAND="zig test src/git_test.zig -lc -lgit2 -I/usr/include -L/usr/lib/x86_64-linux-gnu"
        fi
    fi
fi

# Execute tests
if [ "$RUN_LOCALLY" = true ]; then
    echo "Running tests locally: $TEST_COMMAND"
    eval $TEST_COMMAND
else
    # Docker execution
    echo "Building Docker image..."
    docker-compose build backend
    
    echo "Running tests in Docker: $TEST_COMMAND"
    if [[ "$TEST_COMMAND" == "test-all" || "$TEST_COMMAND" == "test-git" ]]; then
        # Use zig build for predefined test steps
        docker-compose run backend zig build $TEST_COMMAND
    else
        # Run direct command
        docker-compose run backend $TEST_COMMAND
    fi
fi

# Check exit status
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE 