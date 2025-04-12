FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    git \
    libgit2-dev \
    libsqlite3-dev \
    pkg-config \
    unzip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
ARG ZIG_VERSION=0.14.0
RUN curl -sSL https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz | \
    tar -xJ -C /usr/local && \
    mv /usr/local/zig-linux-x86_64-${ZIG_VERSION} /usr/local/zig && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Run tests by default
CMD ["zig", "build", "test"]