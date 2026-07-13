# Root Makefile for Linux Tools Testing Lab

.PHONY: all build-all clean-all gdb-run perf-run strace-run bpftrace-opens bpftrace-syscount bpftrace-writebytes tcpdump-run tcpdump-clean

all: build-all

# Build all Docker images
build-all:
	@echo "=== Building GDB Lab Image ==="
	$(MAKE) -C gdb docker-build
	@echo "\n=== Building Perf Lab Image ==="
	$(MAKE) -C perf docker-build
	@echo "\n=== Building Strace Lab Image ==="
	$(MAKE) -C strace docker-build
	@echo "\n=== Building BPFtrace Lab Image ==="
	$(MAKE) -C bpftrace docker-build
	@echo "\n=== Building Tcpdump Lab Image ==="
	$(MAKE) -C tcpdump docker-build

# GDB Debugging Lab
gdb-run:
	$(MAKE) -C gdb run

# Perf Profiling Lab
perf-run:
	$(MAKE) -C perf run-stat
	$(MAKE) -C perf run-record-slow

# Strace Syscall Tracing Lab
strace-run:
	$(MAKE) -C strace run
	$(MAKE) -C strace run-summary

# BPFtrace eBPF Labs
bpftrace-opens:
	$(MAKE) -C bpftrace run-opens

bpftrace-syscount:
	$(MAKE) -C bpftrace run-syscount

bpftrace-writebytes:
	$(MAKE) -C bpftrace run-writebytes

# Tcpdump Network Capture Labs
tcpdump-run:
	$(MAKE) -C tcpdump run

tcpdump-clean:
	$(MAKE) -C tcpdump clean

# Clean all Docker images and Compose networks
clean-all:
	@echo "=== Cleaning up lab Docker resources ==="
	docker rmi -f lab-gdb lab-perf lab-strace lab-bpftrace lab-tcpdump 2>/dev/null || true
	$(MAKE) -C tcpdump clean || true
