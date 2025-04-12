FROM debian:bookworm-slim

# Detect the host architecture to download the correct Zig binary
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

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

# Create symlinks for libraries in standard paths
RUN ln -s /usr/lib/*/libgit2.so /usr/lib/libgit2.so && \
    ln -s /usr/lib/*/libsqlite3.so /usr/lib/libsqlite3.so

# Install Zig based on architecture
ARG ZIG_VERSION=0.14.0
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ] || [ "$TARGETPLATFORM" = "linux/aarch64" ]; then \
    curl -sSL https://ziglang.org/download/${ZIG_VERSION}/zig-linux-aarch64-${ZIG_VERSION}.tar.xz | \
    tar -xJ -C /usr/local && \
    mv /usr/local/zig-linux-aarch64-${ZIG_VERSION} /usr/local/zig; \
    else \
    curl -sSL https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz | \
    tar -xJ -C /usr/local && \
    mv /usr/local/zig-linux-x86_64-${ZIG_VERSION} /usr/local/zig; \
    fi && \
    ln -s /usr/local/zig/zig /usr/local/bin/zig

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Run tests by default
CMD ["zig", "build", "test"]