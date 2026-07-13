# Perf Lab: CPU Performance Counter Profiler

## Purpose
`perf` is a powerful Linux profiler. Unlike debuggers which analyze *program state*, `perf` analyzes *performance details* (where time is spent, cache misses, branch mispredictions, page faults). It collects metrics using CPU Performance Monitoring Units (PMUs) and periodic kernel sampling.

In this lab, you will compare two versions of a matrix manipulation program to learn how memory layouts impact execution speed and cache utility.

---

## Technical Concept: Cache Locality
Computers load memory into CPU cache lines (typically 64 bytes at a time).
- In C, 2D arrays (like `matrix[2000][2000]`) are laid out **contiguously in row-major order** (`matrix[0][0]`, `matrix[0][1]`, `matrix[0][2]`, ...).
- **Row-Major traversal** (Fast): Accessing elements sequentially means when `matrix[0][0]` is loaded, the next elements in the row are loaded into the cache line, resulting in minimal cache misses.
- **Column-Major traversal** (Slow): Accessing elements column-by-column means jumping `2000 * sizeof(int)` bytes forward in memory for each loop iteration. This completely misses the cache lines, forcing the CPU to fetch from RAM on every loop.

---

## Lab Architecture
Because `perf` accesses CPU performance registers, the host kernel security parameters often limit its usage. The host has `perf_event_paranoid` set to `3` (completely disabling unprivileged usage).
We bypass this by running the profiling container in **`--privileged` mode**, allowing the containerized process to act as root relative to host PMU registers.

---

## Navigation & Execution Commands

### 1. Run Stat Profiling
To compare overall execution metrics (instruction counts, cycles, cache misses):
```bash
make run-stat
```

Observe the output differences:
- **Time elapsed**: The fast version completes in a fraction of the time.
- **Cache-misses**: The slow version will show a high number of cache misses and low instructions-per-cycle (IPC).
- **Instructions & Cycles**: Notice how the CPU wastes cycles idling (stalled) while waiting for RAM fetches in the slow version.

### 2. Record and Analyze Hotspots
To locate the exact function consuming the CPU cycles, we record samples and display a report:
```bash
make run-record-slow
```
This runs:
1. `perf record` to sample the instruction pointer at regular intervals (saving statistics to `perf.data`).
2. `perf report` to parse the database and show which functions (and source lines) are taking the most CPU time.

You will see a text report showing that ~99% of CPU time is spent in `main` (specifically during the column-major update inner loop).
