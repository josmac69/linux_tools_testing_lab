# GDB: Interactive Program Debugger

## Purpose
`gdb` (GNU Debugger) allows you to inspect the execution of another program in real-time, letting you stop execution, examine memory, variables, registers, CPU instructions, and navigate the execution call stack. It is primarily used to analyze program correctness and state (e.g. diagnosing crashes, segmentation faults, and memory corruption) rather than raw resource performance.

---

## Lab Structure
To demonstrate different levels of application debugging, this lab is split into three hands-on sub-labs:

| Lab Directory | Topic | Target Concept | Key Debugger Commands |
|:---|:---|:---|:---|
| **[01_basic_crash](file:///home/josef/github.com/josmac69/linux_tools_testing_lab/gdb/01_basic_crash)** | Basic Programming Crashes | Segment faults, buffer overflows, function frames | `break`, `run`, `print`, `next`, `backtrace` |
| **[02_postgres_debug](file:///home/josef/github.com/josmac69/linux_tools_testing_lab/gdb/02_postgres_debug)** | PostgreSQL Connection Debugging | Process-per-connection attach, database query interception | `gdb -p <pid>`, `break exec_simple_query`, `print query_string` |
| **[03_mysql_debug](file:///home/josef/github.com/josmac69/linux_tools_testing_lab/gdb/03_mysql_debug)** | MySQL/MariaDB Thread Debugging | Thread-per-connection model, multi-threaded state tracing | `info threads`, `break dispatch_command`, `print command` |

---

## Core Debugger Command Cheat Sheet

| Command | Shorthand | Description |
|:---|:---|:---|
| `break [func/line]` | `b` | Set a breakpoint where execution should halt. |
| `run [args]` | `r` | Start the target program (with optional arguments). |
| `continue` | `c` | Resume program execution until the next breakpoint or crash. |
| `next` | `n` | Step over the next line of code (does not enter functions). |
| `step` | `s` | Step into the next line of code (enters functions). |
| `print [var]` | `p` | Evaluate and print the value of a variable or memory address. |
| `backtrace` | `bt` | Print the call stack (ordered list of active function frames). |
| `frame [number]` | `f` | Switch the debugger's focus to a specific stack frame. |
| `info threads` | | List all active OS threads inside a multi-threaded process. |
| `thread [number]` | `t` | Switch the debugger's focus to a specific thread. |
| `quit` | `q` | Detach from the target process and exit GDB. |
