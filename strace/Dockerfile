FROM debian:bookworm-slim

# Install compilation and syscall tracing tools
RUN apt-get update && apt-get install -y \
    gcc \
    strace \
    make \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY target.c Makefile ./

# Pre-compile the target program
RUN make build
