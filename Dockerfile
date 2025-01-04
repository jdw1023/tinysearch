# Docker tinysearch with deps
#   - binaryen
#   - wasm-pack
#   - terser

ARG TINY_REPO=https://github.com/rikuson/tinysearch
ARG TINY_BRANCH=japanese
ARG RUST_IMAGE=filipfilmar/rust_icu_buildenv:1.74.0

FROM $RUST_IMAGE AS builder

ARG TINY_REPO
ARG TINY_BRANCH

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    openssl \
    curl \
    git \
    npm \
    ca-certificates \
    binaryen && \
    npm install terser -g && \
    rm -rf /var/lib/apt/lists/*

# Verify the installation
RUN terser --version

# Install wasm-pack
RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# Verify the installation
RUN wasm-pack --version && which wasm-pack

# Clone the repo and build the binary
RUN git clone --branch "$TINY_BRANCH" "$TINY_REPO" tinysearch && \
    cd tinysearch && \
    cargo build --release --features=bin && \
    cp target/release/tinysearch /usr/local/bin/

FROM $RUST_IMAGE

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    binaryen && \
    rm -rf /var/lib/apt/lists/*

# Copy the build binaries and tinysearch directory
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/cargo/bin/ /usr/local/bin/
# Copy tinysearch build directory to be used as the engine (see `--engine-version` option below)
# This is done because we want to use the same image for building and running tinysearch
# and not depend on crates.io for the engine
COPY --from=builder /build/tinysearch/ /engine

# Initialize crate cache
RUN echo '[{"title":"","body":"","url":""}]' > build.json && \
    tinysearch build.json && \
    rm -r build.json wasm_output

ENTRYPOINT ["tinysearch"]
