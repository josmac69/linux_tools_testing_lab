# GDB Lab: Interactive Program Debugger

## Purpose
`gdb` (GNU Debugger) is a debugger that takes control of a single process. It lets you pause execution, inspect memory, modify variables, view stack frames, set breakpoints, and step through code line-by-line. 

This lab uses a buggy C program to demonstrate how to diagnose runtime crashes (segmentation faults) and investigate internal memory structures.

---

## Lab Architecture
Because debuggers utilize the `ptrace(2)` system call to control target processes, host kernel security (like `kernel.yama.ptrace_scope`) often restricts debugger attachments.
To isolate this, the lab runs in a Docker container with:
- `--cap-add=SYS_PTRACE`: Allows the container to use `ptrace` inside its namespace.
- `--security-opt seccomp=unconfined`: Disables Docker's default syscall restrictions that could block tracing.

---

## Navigation & Execution Commands

### 1. Build and Start the Lab
To start an interactive debugging session inside the container:
```bash
make run
```
You will be placed inside the GDB interactive prompt (`(gdb)`).

### 2. Basic GDB Workflow Commands

Once in the `(gdb)` prompt, run these commands to explore:

#### A. Set a Breakpoint and Run
Set a breakpoint at the `buggy_function` function:
```text
(gdb) break buggy_function
(gdb) run Hello
```
The program will run and stop at the first line of `buggy_function`.

#### B. Step and Inspect Variables
- Show the line of source code that is about to run:
  ```text
  (gdb) list
  ```
- Print the value of the argument `str`:
  ```text
  (gdb) print str
  ```
- Step to the next line (executing `strcpy`):
  ```text
  (gdb) next
  ```
- Print the `buffer` contents:
  ```text
  (gdb) print buffer
  ```
- Continue program execution:
  ```text
  (gdb) continue
  ```

#### C. Diagnosing a Crash (Segmentation Fault)
Run the program without arguments to trigger a null pointer dereference:
```text
(gdb) run
```
GDB will report `Program received signal SIGSEGV, Segmentation fault.`
- Identify the exact line of code where it crashed:
  ```text
  (gdb) backtrace
  ```
- Switch to the main stack frame and print the NULL pointer:
  ```text
  (gdb) frame 1
  (gdb) print ptr
  ```

#### D. Diagnosing a Stack Buffer Overflow
Run the program with a very long argument (greater than 16 bytes):
```text
(gdb) run AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```
The program will crash with a segmentation fault on return, or report memory corruption.
- Use `backtrace` to show how the return address on the stack was overwritten with `0x4141414141414141` (`A` in hex):
  ```text
  (gdb) backtrace
  ```
- Quit GDB:
  ```text
  (gdb) quit
  ```
