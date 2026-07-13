.PHONY: build docker-build run-stat run-record-slow clean

# Compile targets locally without optimizations
build: target_slow.c target_fast.c
	gcc -O0 -o target_slow target_slow.c
	gcc -O0 -o target_fast target_fast.c

# Build the lab Docker image
docker-build:
	docker build -t lab-perf .

# Profile performance statistics (cycles, instructions, cache-misses)
# Run container with --privileged to bypass host perf restrictions
run-stat: docker-build
	@echo "=== Running PERF STAT on SLOW (column-major) target ==="
	docker run --privileged --rm lab-perf perf stat ./target_slow
	@echo "\n=== Running PERF STAT on FAST (row-major) target ==="
	docker run --privileged --rm lab-perf perf stat ./target_fast

# Record cycles on the slow target, then display the report
run-record-slow: docker-build
	@echo "=== Running PERF RECORD on SLOW target ==="
	docker run --privileged -it --rm lab-perf sh -c \
		"perf record -o /tmp/perf.data ./target_slow && perf report -i /tmp/perf.data --stdio"

clean:
	rm -f target_slow target_fast
