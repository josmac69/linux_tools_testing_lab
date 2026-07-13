# Lab: PostgreSQL Performance Profiling with `perf`

## Purpose
`perf` is a low-overhead statistical profiler that samples the CPU instruction pointer and kernel/software events without interrupting the database's execution. This makes it safe for production, in contrast to debuggers like `gdb` which freeze processes when attached.

In this lab, you will learn how to:
1. Profile query execution at the instruction level to see where cycles are spent.
2. Generate interactive Flame Graphs to visualize the database's call-stack hierarchy.
3. Register and trace dynamic user-space probes (uprobes) in PostgreSQL backend executables.

---

## Technical Concepts

### The Frame Pointer Problem and DWARF Stacks
Most pre-compiled Linux distribution packages (including standard Debian/Ubuntu PostgreSQL packages) are built with the compiler optimization `-fomit-frame-pointer` enabled. Without frame pointers, standard frame-pointer stack walking (`perf record -g`) cannot walk the stack, resulting in empty or `[unknown]` stack traces.

To resolve this without rebuilding the package, `perf` can walk the stack using **DWARF debug information** (`--call-graph dwarf`). In this mode, `perf` copies a chunk of the user stack on each sample and uses debug tables (`.eh_frame` / `postgresql-15-dbgsym` debug symbols) to unwind it offline. This produces resolved stacks at the cost of larger data files.

### Flame Graphs
A Flame Graph collapses thousands of recorded stack traces into a single interactive visualization:
- **Y-axis**: Call-stack depth (parent functions on bottom, child functions on top).
- **X-axis**: Total sample width (wider blocks represent functions consuming more CPU cycles cumulative of their callees).
- **Color**: Typically warm shades, randomized to distinguish adjacent functions.

---

## Lab Architecture
The PostgreSQL container runs with the `--privileged` flag. This allows `perf` inside the container to program the host CPU's Performance Monitoring Unit (PMU) registers.

To allow you to view generated assets easily, the container's `/lab` directory is volume-mounted to your local host folder, meaning any generated files (like SVGs) are directly accessible on your host machine.

---

## Execution Walkthrough

### Step 1: Start the PostgreSQL Container
Start the container in the background:
```bash
make run-server
```
Wait a few seconds for the database system to initialize.

### Step 2: Profile Query Metrics with `perf stat`
Run `perf stat` to capture high-level execution statistics (instructions, cycles, instructions-per-cycle (IPC), and cache misses) for a query creating a large table:
```bash
make perf-stat
```
Observe:
- **IPC (Instructions Per Cycle)**: Tells you how efficiently the CPU pipeline is being utilized.
- **Cache-misses**: Higher miss rates indicate memory bottleneck latency.

You can also count specific storage block I/O requests and system call write/fsync events:
```bash
make perf-stat-events
```

### Step 3: Record Stack Traces and Generate a Flame Graph
Run the query under `perf record` sampling at 99 Hz with DWARF stack walking, then automatically process the logs and compile the Flame Graph:
```bash
make perf-record
```
This runs:
1. `perf record` to sample the CPU call stacks.
2. `perf script` to parse the stack trace data.
3. `stackcollapse-perf.pl` and `flamegraph.pl` to collapse the stacks and render them as an SVG.

Once complete, open the generated `postgres_flamegraph.svg` file in your web browser. You will see:
- The `postgres` query execution hierarchy (look for `exec_simple_query` -> `PortalRun` -> `ExecutorRun` -> `ExecutePlan`).
- Helper functions deformed tuples (`slot_deform_heap_tuple`) and doing sorting/hashing.

### Step 4: Register and Trace Dynamic Probes (uprobes)
`perf` can dynamically patch instruction addresses at runtime to insert probes (uprobes) on arbitrary symbols without source code modifications:
```bash
make perf-probe
```
This target:
1. Hooks a dynamic probe named `probe_postgres:exec_simple_query` into the PostgreSQL server's query entrypoint.
2. Records events matching that probe.
3. Triggers test queries.
4. Outputs the recorded trace showing the exact timestamp and process that executed the queries.

---

## Cleaning Up
To stop the container and remove the generated assets:
```bash
make clean
```
