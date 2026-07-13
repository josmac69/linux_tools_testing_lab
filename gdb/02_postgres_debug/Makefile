.PHONY: docker-build run-server run-gdb psql gdb-attach gcore gcore-analyze clean

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

# Run the PostgreSQL server in GDB directly (foreground, interactive)
run-gdb: docker-build
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -it \
		--name $(CONTAINER_NAME) \
		--cap-add=SYS_PTRACE \
		--security-opt seccomp=unconfined \
		-e USE_GDB=1 \
		lab-gdb-postgres

# Enter interactive SQL client console
psql:
	@echo "============================================================"
	@echo "MANUAL SQL CLIENT EXECUTION COMMAND:"
	@echo "  docker exec -it $(CONTAINER_NAME) psql -U postgres"
	@echo "============================================================"
	docker exec -it $(CONTAINER_NAME) psql -U postgres

# Auto-detect client backend PID and attach GDB
gdb-attach:
	@echo "============================================================"
	@echo "MANUAL STEP 1: Query the database to find the connection backend PID:"
	@echo "  psql -U postgres -t -A -c \"SELECT pid FROM pg_stat_activity WHERE backend_type = 'client backend' AND pid <> pg_backend_pid() LIMIT 1;\""
	@echo "============================================================"
	@PID=$$(docker exec -i $(CONTAINER_NAME) psql -U postgres -t -A -c \
		"SELECT pid FROM pg_stat_activity WHERE backend_type = 'client backend' AND pid <> pg_backend_pid() LIMIT 1;" 2>/dev/null || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: No active client psql connection found."; \
		echo "Please run 'make psql' in another terminal window first, then run this."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Detected active connection PID: $$PID"; \
	echo ""; \
	echo "============================================================"; \
	echo "MANUAL STEP 2: Attach GDB to that backend process inside the container:"; \
	echo "  gdb /usr/lib/postgresql/15/bin/postgres $$PID"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres $$PID"; \
	echo "============================================================"; \
	echo ""; \
	docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres $$PID

# Generate a non-destructive core dump of the active client backend process
gcore:
	@echo "============================================================"
	@echo "MANUAL STEP 1: Query the database to find the connection backend PID:"
	@echo "  psql -U postgres -t -A -c \"SELECT pid FROM pg_stat_activity WHERE backend_type = 'client backend' AND pid <> pg_backend_pid() LIMIT 1;\""
	@echo "============================================================"
	@PID=$$(docker exec -i $(CONTAINER_NAME) psql -U postgres -t -A -c \
		"SELECT pid FROM pg_stat_activity WHERE backend_type = 'client backend' AND pid <> pg_backend_pid() LIMIT 1;" 2>/dev/null || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: No active client psql connection found to dump."; \
		echo "Please run 'make psql' in another terminal window first, then run this."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Detected active connection PID: $$PID"; \
	echo ""; \
	echo "============================================================"; \
	echo "MANUAL STEP 2: Capture a non-destructive core dump inside the container:"; \
	echo "  gcore -o /lab/postgres_backend.core $$PID"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gcore -o /lab/postgres_backend.core $$PID"; \
	echo "============================================================"; \
	echo ""; \
	docker exec -it $(CONTAINER_NAME) gcore -o /lab/postgres_backend.core $$PID; \
	echo ""; \
	echo "============================================================"; \
	echo "MANUAL STEP 3: Analyze the core dump offline using GDB:"; \
	echo "  gdb /usr/lib/postgresql/15/bin/postgres /lab/postgres_backend.core.$$PID"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres /lab/postgres_backend.core.$$PID"; \
	echo "============================================================"

# Locate and analyze the core dump inside the container using GDB
gcore-analyze:
	@CORE_FILE=$$(docker exec -i $(CONTAINER_NAME) sh -c "ls /lab/postgres_backend.core.* 2>/dev/null | head -n 1" | tr -d '\r'); \
	if [ -z "$$CORE_FILE" ]; then \
		echo "======================================================================"; \
		echo "Error: No core file found inside the container's /lab/ directory."; \
		echo "Please run 'make gcore' first to generate one."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "============================================================"; \
	echo "MANUAL STEP: Analyze the located core dump $$CORE_FILE offline using GDB:"; \
	echo "  gdb /usr/lib/postgresql/15/bin/postgres $$CORE_FILE"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres $$CORE_FILE"; \
	echo "============================================================"; \
	echo ""; \
	docker exec -it $(CONTAINER_NAME) gdb /usr/lib/postgresql/15/bin/postgres $$CORE_FILE

clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	rm -f postgres_backend.core.*
