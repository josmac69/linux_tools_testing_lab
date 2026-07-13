FROM debian:bookworm-slim

# Install MariaDB Server, debug symbols, linux-perf, git, perl, and sudo
# Standard Debian main repo lacks debug symbols; we append debian-debug repo first
RUN echo 'deb http://deb.debian.org/debian-debug bookworm-debug main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
    mariadb-server \
    mariadb-server-dbgsym \
    mariadb-server-core-dbgsym \
    linux-perf \
    git \
    perl \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Configure mysqld run directory for sockets
RUN mkdir -p /var/run/mysqld && chown -R mysql:mysql /var/run/mysqld /var/lib/mysql

# Install Brendan Gregg's FlameGraph toolset
RUN git clone --depth 1 https://github.com/brendangregg/FlameGraph.git /opt/FlameGraph && \
    ln -s /opt/FlameGraph/stackcollapse-perf.pl /usr/local/bin/stackcollapse-perf.pl && \
    ln -s /opt/FlameGraph/flamegraph.pl /usr/local/bin/flamegraph.pl

WORKDIR /lab

COPY start_mysql.sh ./
RUN chmod +x start_mysql.sh

# Run the startup script to start mysql
CMD ["./start_mysql.sh"]
