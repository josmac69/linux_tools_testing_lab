# Linux Tools Testing Lab

Welcome to the Linux Tools Testing Lab. This repository contains self-contained environments (using Docker containers and Docker Compose) to learn, test, and master five critical Linux debugging, profiling, and tracing tools:

1. **`gdb`** — **A Debugger**: Takes control of a single process to stop execution, inspect memory/variables/stack frames, and step through code. (Program state, not performance).
2. **`perf`** — **A Profiler**: Diagnoses where execution time (cycles, cache misses, branch mispredictions) is spent using hardware Performance Monitoring Units (PMUs) and kernel sampling.
3. **`strace`** — **A Syscall Tracer**: Intercepts and records all system calls made by a process (e.g. `open`, `read`, `write`, `nanosleep`), including their arguments and return values. (User-kernel boundary).
4. **`bpftrace`** — **A Programmable Tracer**: Loads eBPF programs into the kernel to dynamically probe kernel functions (`kprobes`), tracepoints, user-space functions (`uprobes`), and aggregate data efficiently in-kernel.
5. **`tcpdump`** — **A Packet Capturer**: Sniffs raw network packets at the interface level using BPF filters to observe wire-level realities.

---

## Lab Architecture & Docker Strategy

Many of these tools normally require root permissions or specific kernel parameters that can pollute the host or be blocked by security defaults (e.g. `perf_event_paranoid` or `yama/ptrace_scope`).

To make this lab **zero-install** and **safe** for the host system, we run these tools within containerized environments:
- **Capabilities & Privileges**: GDB and Strace run with the `SYS_PTRACE` capability allowed. Perf, BPFtrace, and Tcpdump run in `--privileged` mode to enable PMU access, eBPF maps/probes, and packet sniffing.
- **Shared Mounts**: The BPFtrace lab mounts `/sys/kernel/debug` and `/lib/modules` to let the containerized eBPF compiler access kernel symbols and load probes.
- **Docker Compose Networking**: The Tcpdump lab runs three services: an HTTP server, a client traffic generator, and a sniffer sharing the server's network namespace (`network_mode: service:web-server`).

---

## Prerequisites

- **Docker** (Ensure your user is in the `docker` group to run commands without sudo)
- **Docker Compose**
- **Make**

---

## Navigation & Quick Start

You can control all labs from the root directory using the global `Makefile`.

### 1. Build All Labs
To build the Docker images for all labs:
```bash
make build-all
```

### 2. Run Individual Labs

- **GDB Lab** (Interactive debugger session):
  ```bash
  make gdb-run
  ```
- **Perf Lab** (Stat profiling & cache-miss metrics):
  ```bash
  make perf-run
  ```
- **Strace Lab** (Trace execution & syscall metrics):
  ```bash
  make strace-run
  ```
- **BPFtrace Lab** (Run eBPF tracing scripts):
  ```bash
  # Traces file opens system-wide
  make bpftrace-opens
  # Counts syscalls system-wide
  make bpftrace-syscount
  # Traces write buffer size distributions
  make bpftrace-writebytes
  ```
- **Tcpdump Lab** (Sniff isolated network packets):
  ```bash
  # Starts HTTP server + client + tcpdump sniffer
  make tcpdump-run
  # Stops and cleans up the tcpdump network
  make tcpdump-clean
  ```

### 3. Cleanup All Labs
To remove all container structures and images built for the labs:
```bash
make clean-all
```

---

For deeper explanations of the exercises, concepts, and target programs in each lab, please navigate to the subfolders:
- [`/gdb` README](gdb/README.md)
- [`/perf` README](perf/README.md)
- [`/strace` README](strace/README.md)
- [`/bpftrace` README](bpftrace/README.md)
- [`/tcpdump` README](tcpdump/README.md)