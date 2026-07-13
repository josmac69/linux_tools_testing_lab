.PHONY: docker-build run-server psql perf-stat perf-stat-events perf-record perf-probe clean

CONTAINER_NAME = lab-perf-postgres

docker-build:
	docker build -t lab-perf-postgres .

# Run the PostgreSQL server container with --privileged to allow PMU access
# Mount the local directory to /lab so generated SVGs are accessible on the host
run-server: docker-build
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		--privileged \
		-v $$(pwd):/lab \
		lab-perf-postgres
	@echo "PostgreSQL container started. Wait 5 seconds, then run workloads."

psql:
	docker exec -it $(CONTAINER_NAME) sudo -u postgres psql -U postgres

# Count overall CPU cycles, instructions, and cache misses for a query
perf-stat:
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf stat -d sudo -u postgres psql -q -U postgres postgres -c \
		'DROP TABLE IF EXISTS x; CREATE TABLE x AS SELECT a FROM generate_series(1, 1000000) a;'"

# Count specific kernel storage block requests and write/fsync syscall events
perf-stat-events:
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf stat -e block:block_rq_issue,syscalls:sys_enter_write,syscalls:sys_enter_fsync \
		sudo -u postgres psql -q -U postgres postgres -c \
		'DROP TABLE IF EXISTS x; CREATE TABLE x AS SELECT a FROM generate_series(1, 200000) a;'"

# Record stack traces, collapse them, and generate a Flame Graph
perf-record:
	@echo "Recording CPU profiles (DWARF stack walking) for query execution..."
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf record -F 99 -a -g --call-graph dwarf -o /tmp/perf.data -- \
		sudo -u postgres psql -q -U postgres postgres -c \
		'DROP TABLE IF EXISTS x; CREATE TABLE x AS SELECT a FROM generate_series(1, 1000000) a;'"
	@echo "Generating Flame Graph SVG (/lab/postgres_flamegraph.svg)..."
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf script --no-inline -i /tmp/perf.data | stackcollapse-perf.pl | flamegraph.pl > /lab/postgres_flamegraph.svg"
	@echo "Done! The file 'postgres_flamegraph.svg' is available in your local directory."

# Add dynamic uprobe to exec_simple_query and trace execution
perf-probe:
	@echo "Registering dynamic user-space probe for exec_simple_query..."
	-docker exec -it $(CONTAINER_NAME) perf probe -d probe_postgres:* 2>/dev/null || true
	docker exec -it $(CONTAINER_NAME) perf probe -x /usr/lib/postgresql/15/bin/postgres exec_simple_query
	@echo "Recording events in the background..."
	docker exec -d $(CONTAINER_NAME) perf record -e probe_postgres:exec_simple_query -a -o /tmp/perf.probe.data
	sleep 1
	@echo "Triggering test queries..."
	docker exec -it $(CONTAINER_NAME) sudo -u postgres psql -c "SELECT 42; SELECT 101;"
	sleep 1
	-docker exec -it $(CONTAINER_NAME) killall perf 2>/dev/null || true
	@echo "Dump of recorded dynamic probe events:"
	docker exec -it $(CONTAINER_NAME) perf script -i /tmp/perf.probe.data
	@echo "Removing dynamic probe..."
	docker exec -it $(CONTAINER_NAME) perf probe -d probe_postgres:*

clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	rm -f postgres_flamegraph.svg
