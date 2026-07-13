.PHONY: docker-build run-server mysql gdb-attach gcore clean

# Name of the GDB mysql container
CONTAINER_NAME = lab-gdb-mysql

docker-build:
	docker build -t lab-gdb-mysql .

# Run the MariaDB server in the background (detached)
# Requires SYS_PTRACE and unconfined seccomp to allow GDB register inspection
run-server: docker-build
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		--cap-add=SYS_PTRACE \
		--security-opt seccomp=unconfined \
		lab-gdb-mysql
	@echo "MariaDB container starting. Wait a few seconds, then run 'make mysql'."

# Enter interactive SQL client console
mysql:
	docker exec -it $(CONTAINER_NAME) mariadb -u root

# Attach GDB directly to the main multi-threaded mariadbd process
gdb-attach:
	@PID=$$(docker exec -i $(CONTAINER_NAME) pidof mariadbd 2>/dev/null | tr -d '\r' || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: MariaDB server process not found. Run 'make run-server' first."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Found MariaDB server process PID: $$PID"; \
	echo "Attaching GDB..."; \
	docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd $$PID

# Generate a non-destructive core dump of the main mariadbd process
gcore:
	@PID=$$(docker exec -i $(CONTAINER_NAME) pidof mariadbd 2>/dev/null | tr -d '\r' || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: MariaDB server process not found. Run 'make run-server' first."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Found MariaDB server process PID: $$PID"; \
	echo "Generating non-destructive core dump..."; \
	docker exec -it $(CONTAINER_NAME) gcore -o /lab/mariadb.core $$PID
	@echo "Core dump successfully saved to /lab/mariadb.core.<pid> inside container."
	@echo "To analyze the core dump offline, run:"
	@echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd /lab/mariadb.core.$$PID"

clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
