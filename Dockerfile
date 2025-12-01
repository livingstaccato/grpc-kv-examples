# Dockerfile for gRPC Cross-Language EC Curve Compatibility Testing
#
# This Dockerfile sets up an environment with all language runtimes and tools
# needed to test gRPC TLS with P-256, P-384, and P-521 elliptic curves.
#
# Languages included:
# - Go (server + client, uses crypto/tls - full curve support)
# - Python (gRPC with BoringSSL - P-256 only bug)
# - Ruby (gRPC with BoringSSL - P-256 only bug)
# - C++ (gRPC with BoringSSL - P-256 only bug)
# - Node.js (gRPC with OpenSSL - full curve support)
# - Java (gRPC with Netty/JDK TLS - full curve support)
# - Kotlin (uses Java gRPC)
# - Scala (uses Java gRPC)
# - Rust (tonic with rustls - full curve support)
# - Dart (native TLS - full curve support)
# - C# (gRPC with SslStream - full curve support)
#
# Build: docker build -t grpc-curve-test .
# Run:   docker run -it grpc-curve-test

FROM ubuntu:24.04

LABEL maintainer="grpc-kv-examples"
LABEL description="gRPC cross-language EC curve compatibility testing environment"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base development tools and libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    # SSL/TLS libraries
    libssl-dev \
    openssl \
    # Protobuf
    protobuf-compiler \
    libprotobuf-dev \
    # gRPC C++ dependencies
    libgrpc-dev \
    libgrpc++-dev \
    protobuf-compiler-grpc \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Go (1.21+)
# ============================================================
ENV GO_VERSION=1.22.0
RUN wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# ============================================================
# Python 3.11+ with pip
# ============================================================
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python gRPC packages (stock version with P-256 only bug)
RUN pip3 install --break-system-packages \
    grpcio \
    grpcio-tools \
    protobuf

# ============================================================
# Ruby 3.x with bundler
# ============================================================
RUN apt-get update && apt-get install -y \
    ruby \
    ruby-dev \
    && rm -rf /var/lib/apt/lists/*
RUN gem install bundler grpc google-protobuf

# ============================================================
# Node.js 20.x LTS
# ============================================================
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Java 21 (OpenJDK)
# ============================================================
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# ============================================================
# Gradle 8.x (for Java/Kotlin/Scala builds)
# ============================================================
ENV GRADLE_VERSION=8.5
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
    unzip -q gradle-${GRADLE_VERSION}-bin.zip -d /opt && \
    rm gradle-${GRADLE_VERSION}-bin.zip && \
    ln -s /opt/gradle-${GRADLE_VERSION}/bin/gradle /usr/local/bin/gradle

# ============================================================
# Kotlin (via SDKMAN or standalone)
# ============================================================
ENV KOTLIN_VERSION=1.9.22
RUN wget -q https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip && \
    unzip -q kotlin-compiler-${KOTLIN_VERSION}.zip -d /opt && \
    rm kotlin-compiler-${KOTLIN_VERSION}.zip && \
    ln -s /opt/kotlinc/bin/kotlin /usr/local/bin/kotlin && \
    ln -s /opt/kotlinc/bin/kotlinc /usr/local/bin/kotlinc

# ============================================================
# Scala 3.x with sbt
# ============================================================
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | apt-key add - && \
    apt-get update && apt-get install -y sbt && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Rust (latest stable)
# ============================================================
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup update stable

# ============================================================
# Dart SDK
# ============================================================
RUN wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | tee /etc/apt/sources.list.d/dart_stable.list && \
    apt-get update && apt-get install -y dart && \
    rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/lib/dart/bin:${PATH}"

# ============================================================
# .NET SDK 8.0
# ============================================================
RUN wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && apt-get install -y dotnet-sdk-8.0 && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Working directory setup
# ============================================================
WORKDIR /workspace

# Copy the project files
COPY . /workspace/

# Install language-specific dependencies
# Go dependencies
RUN cd /workspace/go && go mod download || true

# Node.js dependencies
RUN cd /workspace/nodejs && npm install || true

# Dart dependencies
RUN cd /workspace/dart && dart pub get || true

# Rust dependencies (build)
RUN cd /workspace/rust && cargo build --release || true

# Create PKCS#8 versions of EC keys for Rust compatibility
RUN for curve in secp256r1 secp384r1 secp521r1; do \
    openssl pkcs8 -topk8 -nocrypt \
        -in /workspace/certs/ec-${curve}-mtls-client.key \
        -out /workspace/certs/ec-${curve}-mtls-client.pkcs8.key; \
    openssl pkcs8 -topk8 -nocrypt \
        -in /workspace/certs/ec-${curve}-mtls-server.key \
        -out /workspace/certs/ec-${curve}-mtls-server.pkcs8.key; \
    done

# Set up environment for testing
ENV PLUGIN_HOST=localhost
ENV PLUGIN_PORT=50051

# Default command
CMD ["/bin/bash"]
