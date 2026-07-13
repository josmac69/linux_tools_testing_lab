FROM debian:bookworm-slim

# Install compilation and debugging tools
RUN apt-get update && apt-get install -y \
    gcc \
    gdb \
    make \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY target.c Makefile ./

# Pre-compile the target program
RUN make build

# Default to running GDB on our target
CMD ["gdb", "./target"]
