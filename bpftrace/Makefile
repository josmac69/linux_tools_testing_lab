.PHONY: build docker-build run-opens run-syscount run-writebytes clean

# Compile the activity generator target program
build: target.c
	gcc -o target target.c

# Build the lab Docker image
docker-build:
	docker build -t lab-bpftrace .

# Common volumes and flags needed for bpftrace container execution
# Needs host debugfs, modules, and src mounted to compile eBPF code against host kernel
BPFTRACE_RUN = docker run --privileged --rm \
	-v /sys/kernel/debug:/sys/kernel/debug:rw \
	-v /lib/modules:/lib/modules:ro \
	-v /usr/src:/usr/src:ro \
	lab-bpftrace

# Lab 1: Trace file opens system-wide
run-opens: docker-build
	@echo "=== Starting bpftrace file opens tracer (Ctrl+C to stop) ==="
	$(BPFTRACE_RUN) bpftrace ./scripts/fileopens.bt

# Lab 2: Aggregated syscalls counts per process
run-syscount: docker-build
	@echo "=== Starting bpftrace syscall counter (Ctrl+C to stop, prints every 5s) ==="
	$(BPFTRACE_RUN) bpftrace ./scripts/syscount.bt

# Lab 3: Capture write buffer size distributions specifically for our target activity generator
run-writebytes: docker-build
	@echo "=== Starting bpftrace write buffer size histogram ==="
	@echo "This will run our target activity generator, trace its writes, and print a histogram on exit."
	@echo "Let it run for 5-10 seconds, then press Ctrl+C to see the histogram."
	$(BPFTRACE_RUN) bpftrace -c "./target" ./scripts/writebytes.bt

clean:
	rm -f target
