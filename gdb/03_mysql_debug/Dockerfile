FROM debian:bookworm-slim

# Install MariaDB Server, GDB, procps, and debug symbols
# Standard Debian main repo lacks debug symbols; we append debian-debug repo first
RUN echo 'deb http://deb.debian.org/debian-debug bookworm-debug main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
    mariadb-server \
    mariadb-server-dbgsym \
    gdb \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

# Configure mysqld run directory for sockets
RUN mkdir -p /var/run/mysqld && chown -R mysql:mysql /var/run/mysqld /var/lib/mysql

COPY start_mysql.sh ./
RUN chmod +x start_mysql.sh

CMD ["./start_mysql.sh"]
