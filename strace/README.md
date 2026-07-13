# Strace Lab: System Call Tracer

## Purpose
`strace` is a diagnostic, debugging, and instructional tool for Linux. It intercepts and records the system calls (syscalls) made by a process, along with the signals received. 

It acts exclusively at the **user-kernel boundary**. It does not know what happens inside user-space functions (like C's `printf`), nor what happens inside kernel functions; it only sees the request messages sent from user space to the kernel and the kernel's responses.

---

## Technical Concept: The User-Kernel Boundary
When a program needs to interact with hardware (e.g. printing to stdout, writing to disk, allocating memory, sleeping, or querying network interfaces), it cannot do so directly due to CPU security rings (User Mode vs. Kernel Mode).
Instead, it invokes a **system call** to request that the kernel perform the action on its behalf.

- `printf(...)` (C library function) -> calls `write(...)` system call.
- `usleep(...)` (C library function) -> calls `nanosleep(...)` system call.
- `open(...)` (C library function) -> calls `openat(...)` system call.

---

## Lab Architecture
Because `strace` relies on the kernel's `ptrace` interface to intercept and inspect syscall registers, it requires special permissions.
We run the container with **`--cap-add=SYS_PTRACE`**, allowing the containerized `strace` process to trace its sibling processes within the container network.

---

## Navigation & Execution Commands

### 1. Run Complete Syscall Trace
To execute the target program and view every system call in real time:
```bash
make run
```

Observe the output lines. A typical line looks like this:
```text
openat(AT_FDCWD, "strace_demo.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 3
```
- **`openat`**: The name of the system call.
- **`AT_FDCWD, "strace_demo.txt", ...`**: The arguments passed from user-space.
- **`= 3`**: The return value from the kernel (in this case, file descriptor 3).

Look for the key system calls executed by our target program:
- `openat` (for `strace_demo.txt`)
- `write` (writing "Hello from the strace lab!")
- `nanosleep` (the 100ms pause)
- `read` (reading the file back)
- `unlinkat` (deleting the file)

### 2. Run Syscall Summary Histogram
To count and group system calls to see where a process spends its time:
```bash
make run-summary
```

This runs `strace -c`, producing a table showing:
- `% time` spent in each type of system call.
- Total `seconds` accumulated.
- Average time per call (`usecs/call`).
- Number of `calls`.
- Number of `errors` (if any syscall failed).
