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
echo "=== Starting MariaDB Server ==="
exec /usr/sbin/mariadbd --user=mysql --console
