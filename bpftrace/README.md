# BPFtrace Lab: Programmable eBPF Tracing

## Purpose
`bpftrace` is a high-level tracing language for Linux eBPF (Extended Berkeley Packet Filter). eBPF allows you to run sandboxed programs inside the Linux kernel without changing kernel source code or loading kernel modules.

`bpftrace` is highly flexible. It lets you attach probes to:
- **Tracepoints**: Stable hook points built into the kernel source (`tracepoint:syscalls:sys_enter_openat`).
- **Kprobes / Kretprobes**: Dynamic hooks into any kernel function (`kprobe:vfs_read`).
- **Uprobes / Uretprobes**: Dynamic hooks into user-space functions.
- **Intervals**: Time-based triggers (`interval:s:5`).

---

## Technical Concept: In-Kernel Aggregation
Traditional tracers like `strace` incur high performance overhead. Every system call triggers a context switch from kernel to user space to copy logs to the tracer.
eBPF aggregates data (counts, averages, histograms) **directly inside the kernel** using BPF Maps. It only sends the final summarized data back to user space, making it safe for production profiling.

---

## Lab Architecture
BPF programs require root capabilities to load code into the kernel. The container runs with:
- **`--privileged`**: Gives the container root privileges over kernel features.
- **`-v /sys/kernel/debug:/sys/kernel/debug:rw`**: Accesses the kernel debug filesystem (needed to locate tracepoints).
- **`-v /lib/modules:/lib/modules:ro`** and **`-v /usr/src:/usr/src:ro`**: Provides the kernel headers and symbols so `bpftrace` can compile the eBPF program against your running kernel on-the-fly.

---

## Navigation & Execution Commands

### 1. Trace File Opens System-Wide
To print a message every time a process opens a file:
```bash
make run-opens
```
*Tip*: Try opening another terminal on the host and running `cat /etc/passwd` or `ls` to watch the container capture it system-wide!

### 2. Count System Calls System-Wide
To aggregate system calls in the kernel and print a summary of top process activity every 5 seconds:
```bash
make run-syscount
```
Observe how the processes generating the most system calls (e.g. databases, browsers, docker daemons, or our own shell scripts) are accumulated.

### 3. Analyze Write Buffer Sizes Histogram
To profile the size of data writes made by a specific program and render a log2 histogram:
```bash
make run-writebytes
```
This command runs our custom `target` program (which loops, writing random buffer sizes to a file). 
- Let the program run for 5–10 seconds.
- Press **`Ctrl+C`** to stop it.
- Observe the printed ASCII histogram showing the distribution of write buffer sizes.
