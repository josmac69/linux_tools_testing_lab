FROM debian:bookworm-slim

# Install compilation and perf profiling tools
RUN apt-get update && apt-get install -y \
    gcc \
    linux-perf \
    make \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY target_slow.c target_fast.c Makefile ./

# Pre-compile the target programs without optimization so loops aren't optimized away
RUN make build
