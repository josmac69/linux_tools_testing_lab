FROM debian:bookworm-slim

# Install PostgreSQL 15, GDB, procps, and debug symbols
# Standard Debian main repo lacks debug symbols; we append debian-debug repo first
RUN echo 'deb http://deb.debian.org/debian-debug bookworm-debug main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
    postgresql-15 \
    postgresql-15-dbgsym \
    gdb \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY start_postgres.sh ./
RUN chmod +x start_postgres.sh

# Run the startup script to start postgres
CMD ["./start_postgres.sh"]
