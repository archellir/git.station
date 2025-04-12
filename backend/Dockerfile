FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    libgit2-dev \
    libsqlite3-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN curl -sSL https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz | tar -xJ --strip-components=1 -C /usr/local/

# Create app directory
WORKDIR /app

# Copy source files
COPY . .

# Build the application
RUN zig build

# Create directories
RUN mkdir -p /app/repositories /app/data

# Expose port
EXPOSE 8080

# Run the server
CMD ["./zig-out/bin/git.station"] 