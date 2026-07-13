#!/bin/bash
set -e

# Ensure PostgreSQL run and socket directories exist with correct permissions
mkdir -p /var/run/postgresql/15-main.pg_stat_tmp
chown -R postgres:postgres /var/run/postgresql /var/lib/postgresql /etc/postgresql

# Adjust pg_hba.conf to allow passwordless connections (trust) for local convenience
PG_HBA="/etc/postgresql/15/main/pg_hba.conf"
if [ -f "$PG_HBA" ]; then
    echo "local all all trust" > "$PG_HBA"
    echo "host all all 127.0.0.1/32 trust" >> "$PG_HBA"
    echo "host all all ::1/128 trust" >> "$PG_HBA"
    echo "host all all all trust" >> "$PG_HBA"
fi

# Run PostgreSQL daemon in the foreground as the postgres user
echo "=== Starting PostgreSQL 15 Server ==="
exec sudo -u postgres /usr/lib/postgresql/15/bin/postgres \
    -D /var/lib/postgresql/15/main \
    -c config_file=/etc/postgresql/15/main/postgresql.conf
