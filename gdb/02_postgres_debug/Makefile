.PHONY: docker-build run-server psql gdb-attach gcore clean

# Name of the GDB postgres container
CONTAINER_NAME = lab-gdb-postgres

docker-build:
	docker build -t lab-gdb-postgres .

# Run the PostgreSQL server in the background (detached)
# Requires SYS_PTRACE and unconfined seccomp to allow GDB register inspection
run-server: docker-build
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		--cap-add=SYS_PTRACE \
		--security-opt seccomp=unconfined \
		lab-gdb-postgres
	@echo "PostgreSQL container starting. Wait a few seconds, then run 'make psql'."

# Enter interactive SQL client console
psql:
	docker exec -it $(CONTAINER_NAME) psql -U postgres

# Auto-detect client backend PID and attach GDB
gdb-attach:
	@PID=$$(docker exec -i $(CONTAINER_NAME) psql -U postgres -t -A -c \
		"SELECT pid FROM pg_stat_activity WHERE backend_type = 'client backend' AND pid <> pg_backend_pid() LIMIT 1;" 2>/dev/null || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: No active client psql connection found."; \
		echo "Please run 'make psql' in another terminal window first, then run this."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Found active PostgreSQL client backend PID: $$PID"; \
	echo "Attaching GDB to backend process..."; \
	docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres $$PID

# Generate a non-destructive core dump of the active client backend process
gcore:
	@PID=$$(docker exec -i $(CONTAINER_NAME) psql -U postgres -t -A -c \
		"SELECT pid FROM pg_stat_activity WHERE backend_type = 'client backend' AND pid <> pg_backend_pid() LIMIT 1;" 2>/dev/null || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: No active client psql connection found to dump."; \
		echo "Please run 'make psql' in another terminal window first, then run this."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Found active PostgreSQL client backend PID: $$PID"; \
	echo "Generating non-destructive core dump..."; \
	docker exec -it $(CONTAINER_NAME) gcore -o /lab/postgres_backend.core $$PID
	@echo "Core dump successfully saved to /lab/postgres_backend.core.<pid> inside container."
	@echo "To analyze the core dump offline, run:"
	@echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres /lab/postgres_backend.core.$$PID"

clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
