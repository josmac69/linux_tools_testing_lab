# Root Makefile for Linux Tools Testing Lab

.PHONY: all build-all clean-all gdb-run gdb-postgres-run gdb-postgres-psql gdb-postgres-attach gdb-postgres-gcore gdb-postgres-gcore-analyze gdb-mysql-run gdb-mysql-client gdb-mysql-attach gdb-mysql-gcore gdb-mysql-gcore-analyze perf-run strace-run bpftrace-opens bpftrace-syscount bpftrace-writebytes tcpdump-run tcpdump-clean

all: build-all

# Build all Docker images
build-all:
	@echo "=== Building GDB Sub-Lab Images ==="
	$(MAKE) -C gdb build
	@echo "\n=== Building Perf Lab Image ==="
	$(MAKE) -C perf docker-build
	@echo "\n=== Building Strace Lab Image ==="
	$(MAKE) -C strace docker-build
	@echo "\n=== Building BPFtrace Lab Image ==="
	$(MAKE) -C bpftrace docker-build
	@echo "\n=== Building Tcpdump Lab Image ==="
	$(MAKE) -C tcpdump docker-build

# GDB Lab 1: Basic Programming Crash Debugging
gdb-run:
	$(MAKE) -C gdb/01_basic_crash run

# GDB Lab 2: PostgreSQL Connection Debugging
gdb-postgres-run:
	$(MAKE) -C gdb/02_postgres_debug run-server

gdb-postgres-psql:
	$(MAKE) -C gdb/02_postgres_debug psql

gdb-postgres-attach:
	$(MAKE) -C gdb/02_postgres_debug gdb-attach

gdb-postgres-gcore:
	$(MAKE) -C gdb/02_postgres_debug gcore

gdb-postgres-gcore-analyze:
	$(MAKE) -C gdb/02_postgres_debug gcore-analyze

# GDB Lab 3: MySQL/MariaDB Thread Debugging
gdb-mysql-run:
	$(MAKE) -C gdb/03_mysql_debug run-server

gdb-mysql-client:
	$(MAKE) -C gdb/03_mysql_debug mysql

gdb-mysql-attach:
	$(MAKE) -C gdb/03_mysql_debug gdb-attach

gdb-mysql-gcore:
	$(MAKE) -C gdb/03_mysql_debug gcore

gdb-mysql-gcore-analyze:
	$(MAKE) -C gdb/03_mysql_debug gcore-analyze

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
	@echo "=== Cleaning up GDB lab containers ==="
	$(MAKE) -C gdb clean || true
	@echo "=== Cleaning up lab Docker images ==="
	docker rmi -f lab-gdb-basic lab-gdb-postgres lab-gdb-mysql lab-perf lab-strace lab-bpftrace lab-tcpdump 2>/dev/null || true
	$(MAKE) -C tcpdump clean || true

