.PHONY: docker-build run-server mysql gdb-attach gcore gcore-analyze clean

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
	@echo "============================================================"
	@echo "MANUAL SQL CLIENT EXECUTION COMMAND:"
	@echo "  docker exec -it $(CONTAINER_NAME) mariadb -u root"
	@echo "============================================================"
	docker exec -it $(CONTAINER_NAME) mariadb -u root

# Attach GDB directly to the main multi-threaded mariadbd process
gdb-attach:
	@echo "============================================================"
	@echo "MANUAL STEP 1: Find the PID of the running MariaDB daemon process:"
	@echo "  pidof mariadbd"
	@echo "============================================================"
	@PID=$$(docker exec -i $(CONTAINER_NAME) pidof mariadbd 2>/dev/null | tr -d '\r' || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: MariaDB server process not found. Run 'make run-server' first."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Detected daemon process PID: $$PID"; \
	echo ""; \
	echo "============================================================"; \
	echo "MANUAL STEP 2: Attach GDB to the daemon PID inside the container:"; \
	echo "  gdb /usr/sbin/mariadbd $$PID"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd $$PID"; \
	echo "============================================================"; \
	echo ""; \
	docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd $$PID

# Generate a non-destructive core dump of the main mariadbd process
gcore:
	@echo "============================================================"
	@echo "MANUAL STEP 1: Find the PID of the running MariaDB daemon process:"
	@echo "  pidof mariadbd"
	@echo "============================================================"
	@PID=$$(docker exec -i $(CONTAINER_NAME) pidof mariadbd 2>/dev/null | tr -d '\r' || true); \
	if [ -z "$$PID" ]; then \
		echo "======================================================================"; \
		echo "Error: MariaDB server process not found. Run 'make run-server' first."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "Detected daemon process PID: $$PID"; \
	echo ""; \
	echo "============================================================"; \
	echo "MANUAL STEP 2: Dump daemon process memory inside the container:"; \
	echo "  gcore -o /lab/mariadb.core $$PID"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gcore -o /lab/mariadb.core $$PID"; \
	echo "============================================================"; \
	echo ""; \
	docker exec -it $(CONTAINER_NAME) gcore -o /lab/mariadb.core $$PID; \
	echo ""; \
	echo "============================================================"; \
	echo "MANUAL STEP 3: Analyze the core dump offline using GDB:"; \
	echo "  gdb /usr/sbin/mariadbd /lab/mariadb.core.$$PID"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd /lab/mariadb.core.$$PID"; \
	echo "============================================================"

# Locate and analyze the core dump inside the container using GDB
gcore-analyze:
	@CORE_FILE=$$(docker exec -i $(CONTAINER_NAME) sh -c "ls /lab/mariadb.core.* 2>/dev/null | head -n 1" | tr -d '\r'); \
	if [ -z "$$CORE_FILE" ]; then \
		echo "======================================================================"; \
		echo "Error: No core file found inside the container's /lab/ directory."; \
		echo "Please run 'make gcore' first to generate one."; \
		echo "======================================================================"; \
		exit 1; \
	fi; \
	echo "============================================================"; \
	echo "MANUAL STEP: Analyze the located core dump $$CORE_FILE offline using GDB:"; \
	echo "  gdb /usr/sbin/mariadbd $$CORE_FILE"; \
	echo ""; \
	echo "Under-the-hood wrapper command:"; \
	echo "  docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd $$CORE_FILE"; \
	echo "============================================================"; \
	echo ""; \
	docker exec -it $(CONTAINER_NAME) gdb /usr/sbin/mariadbd $$CORE_FILE

clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	rm -f mariadb.core.*
