# Linux Performance Profiling Lab (`perf`)

Welcome to the **Performance Profiling Lab**. This directory contains structured exercises and environments designed to teach you how to analyze CPU execution bottlenecks, memory hierarchy access patterns, and database engine internals using the Linux `perf` tool.

---

## Lab Directory Structure

The lab is divided into three progressive sub-labs:

### [01_matrix_cache](01_matrix_cache): CPU Cache Locality & Hardware Events
*   **Concepts**: CPU L1/LLC cache lines, spatial locality, and execution profiling.
*   **Exercise**: Contrast row-major vs. column-major 2D matrix traversal.
*   **Tooling**: Use `perf stat` to count CPU cycles, instructions, and cache misses, and `perf record` to map execution hotspots.

### [02_postgres_perf](02_postgres_perf): PostgreSQL Database Query Profiling
*   **Concepts**: DWARF stack unwinding, system-wide database profiling, and user-space dynamic probes (uprobes).
*   **Exercise**: Profile query execution for a table creation query, register dynamic uprobes on the PostgreSQL backend parser/executor, and compile interactive Flame Graphs.
*   **Tooling**: `perf stat` (including block I/O tracepoints), `perf record` (DWARF call-graph collection), and Brendan Gregg's FlameGraph perl scripts.

### [03_mysql_perf](03_mysql_perf): MySQL/MariaDB Thread-Level Profiling
*   **Concepts**: Multi-threaded process profiling, database InnoDB storage engine internals, and identifying uninstrumented lock contention.
*   **Exercise**: Generate a heavy CPU workload using the MariaDB `BENCHMARK()` function and record all executing threads to construct a thread-level Flame Graph.
*   **Tooling**: `perf stat` and `perf record` with DWARF call-stack walking.

---

## Core Performance Engineering Concepts

### 1. Low-Overhead Statistical Profiling
Unlike debuggers (such as `gdb`) which halt the execution of target processes to examine state, `perf` operates as a statistical profiler. It programmatically samples CPU registers and PMU (Performance Monitoring Unit) counters at specified frequencies (e.g., 99 Hz), resulting in negligible runtime overhead. This makes `perf` safe for production diagnostics.

### 2. The Frame Pointer Optimization Challenge
Most production database binaries (e.g., standard Debian package builds of PostgreSQL/MariaDB) are compiled with `-fomit-frame-pointer` to free up an extra CPU register. Without frame pointers, traditional stack walking fails, producing empty or `[unknown]` stacks.
To bypass this, we configure `perf` to capture stack snapshots using **DWARF debug information** (`--call-graph dwarf`). The tool then uses debug symbol files (`*-dbgsym`) to resolve symbol stacks offline.

### 3. Dynamic User-Space Probes (uprobes)
`perf` can dynamically patch active user-space binary instructions to inject dynamic probes (uprobes) on arbitrary symbols (like `exec_simple_query` in PostgreSQL) without source modifications or recompilation.

---

## Getting Started

### Prerequisites
`perf` requires access to host CPU PMU counters. Containers in these labs must be run in **privileged** mode (`--privileged`). 
> [!WARNING]
> If you are running inside a virtual machine or a cloud instance, make sure virtualized PMU support (vPMU) is enabled on your hypervisor. Otherwise, hardware events like cache misses or cycles may return as zero or fail.

### Build the Lab Images
You can build all the performance profiling images from the top-level repository workspace:
```bash
make build-all
```

### Running the Labs
Refer to the `README.md` inside each sub-directory for detailed instructions, commands, and expected outcomes:
*   [Matrix Cache Locality README](01_matrix_cache/README.md)
*   [PostgreSQL Profiling README](02_postgres_perf/README.md)
*   [MySQL/MariaDB Profiling README](03_mysql_perf/README.md)
