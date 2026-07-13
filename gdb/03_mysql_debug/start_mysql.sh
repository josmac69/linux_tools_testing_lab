#!/bin/bash
set -e

# Ensure proper permissions on database and runtime socket directories
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

# Initialize the default system tables if not already present
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database system tables..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start the MariaDB daemon in the foreground, logging directly to console
# Note: --innodb-use-native-aio=OFF disables io_uring kernel workers, preventing GDB/gcore hangs
echo "=== Starting MariaDB Server ==="
if [ "$USE_GDB" = "1" ]; then
    exec sudo -u mysql gdb \
        -ex "handle SIGUSR1 noprint nostop" \
        -ex "handle SIGUSR2 noprint nostop" \
        -ex "handle SIGPIPE noprint nostop" \
        -ex "handle SIGALRM noprint nostop" \
        --args /usr/sbin/mariadbd --console --skip-stack-trace --innodb-use-native-aio=OFF
else
    exec /usr/sbin/mariadbd --user=mysql --console --innodb-use-native-aio=OFF
fi
