# Lab: MySQL/MariaDB Performance Profiling with `perf`

## Purpose
`mysqld`/`mariadbd` uses a single-process, thread-per-connection architecture. Profiling database performance requires analyzing CPU cycles across all active connection threads, thread coordination locks, and storage engine internals.

In this lab, you will learn how to:
1. Measure CPU instructions and cycles during query execution using the MariaDB `BENCHMARK()` function.
2. Generate thread-level Flame Graphs to identify execution bottlenecks.
3. Understand why OS-level tools like `perf` are needed to diagnose lock contentions that are invisible to the database's own `performance_schema`.

---

## Technical Concepts

### Thread-per-Connection Architecture
When a client connects to MariaDB/MySQL, a connection manager thread spawns or assigns a thread to handle that connection. This connection thread executes the parser, query optimizer, and requests pages from the storage engine (InnoDB).
- `perf record -p PID` records activity across **all** active threads in the process.
- Stacks are resolved using DWARF (`--call-graph dwarf`) to bridge standard Distro builds that lack frame pointers (`-fomit-frame-pointer`).

### Gaps in `performance_schema`
While MariaDB's `performance_schema` is a powerful tool for profiling queries and lock wait stages inside the database engine, **not all locks are instrumented**.
For example, low-level page and block read-write locks (`block rw-lock` contention) are often uninstrumented in standard releases. When these lock contentions happen, the database console will show no issues, but the server CPU usage will spike or stall. OS-level `perf` profiling is the only way to locate these hotspots by tracing the actual thread lock calls in the DSO libraries.

---

## Execution Walkthrough

### Step 1: Start the MariaDB Container
Start the container in the background:
```bash
make run-server
```
Wait a few seconds for the database to complete its initialization.

### Step 2: Measure CPU Metrics with `perf stat`
Run `perf stat` on a CPU-intensive statement. We use the MariaDB `BENCHMARK(count, expr)` function, which executes the given expression repeatedly (in this case, 5 million times), generating a high-density, controlled CPU workload:
```bash
make perf-stat
```
Take note of:
- **Cycles and Instructions**: Shows total CPU execution overhead.
- **IPC (Instructions Per Cycle)**: Measures execution throughput.

### Step 3: Record and Generate a Flame Graph
Record the execution stack traces at 99 Hz and generate a Flame Graph:
```bash
make perf-record
```
This target:
1. Traces the MariaDB backend threads while executing a 10-million loop benchmark query.
2. Generates the collapsed stack logs.
3. Renders them to `mysql_flamegraph.svg`.

Once complete, open `mysql_flamegraph.svg` in a web browser on your host machine. Look for:
- The SQL command parser and dispatcher (`dispatch_command` -> `mysql_parse` -> `mysql_execute_command`).
- The storage engine hand-off (`ha_mariadb` / `handler` -> `row_search_mvcc`).
- InnoDB internal hash searches and page retrievals.

---

## Cleaning Up
To stop the container and delete the generated SVGs:
```bash
make clean
```
