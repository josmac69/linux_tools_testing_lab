.PHONY: docker-build run-server mysql perf-stat perf-record clean

CONTAINER_NAME = lab-perf-mysql

docker-build:
	docker build -t lab-perf-mysql .

# Run the MariaDB/MySQL container with --privileged to allow PMU access
# Mount the local directory to /lab so generated SVGs are accessible on the host
run-server: docker-build
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		--privileged \
		-v $$(pwd):/lab \
		lab-perf-mysql
	@echo "MariaDB container started. Wait 5 seconds, then run workloads."

mysql:
	docker exec -it $(CONTAINER_NAME) mariadb -u root

# Count overall CPU cycles, instructions, and L1 cache hits/misses for a query
perf-stat:
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf stat -d mariadb -u root -e 'SELECT BENCHMARK(5000000, ENCODE(\"hello\", \"goodbye\"));'"

# Record stack traces, collapse them, and generate a Flame Graph
perf-record:
	@echo "Recording CPU profiles for thread-level execution..."
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf record -F 99 -a -g --call-graph dwarf -o /tmp/perf.data -- \
		mariadb -u root -e 'SELECT BENCHMARK(10000000, ENCODE(\"hello\", \"goodbye\"));'"
	@echo "Generating Flame Graph SVG (/lab/mysql_flamegraph.svg)..."
	docker exec -it $(CONTAINER_NAME) sh -c \
		"perf script --no-inline -i /tmp/perf.data | stackcollapse-perf.pl | flamegraph.pl > /lab/mysql_flamegraph.svg"
	@echo "Done! The file 'mysql_flamegraph.svg' is available in your local directory."

clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	rm -f mysql_flamegraph.svg
