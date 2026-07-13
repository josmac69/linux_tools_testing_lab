FROM debian:bookworm-slim

# Install tcpdump and curl
RUN apt-get update && apt-get install -y \
    tcpdump \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Default command to run tcpdump
ENTRYPOINT ["tcpdump"]
