FROM debian:bookworm-slim

# Install bpftrace, compilation tools, and procps (for ps/pgrep)
RUN apt-get update && apt-get install -y \
    bpftrace \
    gcc \
    make \
    procps \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY scripts/ ./scripts/
COPY target.c Makefile ./

# Pre-compile the target activity generator
RUN make build
