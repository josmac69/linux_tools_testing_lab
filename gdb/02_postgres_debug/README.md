# GDB Lab: Debugging PostgreSQL Backend Connections

## Purpose
This lab demonstrates how to debug database engine queries by attaching GDB directly to an active PostgreSQL connection backend process.

PostgreSQL uses a **process-per-connection** model. When a client connects, the main postmaster daemon spawns (forks) a new `postgres` child process (often called the "backend") dedicated entirely to that client's session. This architecture makes debugging clean because we can isolate and debug a single connection PID without impacting other sessions.

---

## Hands-On Exercise: Intercepting a Query

### Step 1: Start the PostgreSQL Daemon
Start the PostgreSQL container in the background:
```bash
make run-server
```

### Step 2: Open a Client Session
In a **new terminal window**, connect to PostgreSQL via `psql`:
```bash
make psql
```
Keep this window open. This session represents our client connection.

### Step 3: Attach GDB to the Client Backend
In your **original terminal window**, attach GDB to the backend process handling your `psql` connection:
```bash
make gdb-attach
```
The Makefile query automatically locates your client backend's process ID (PID) from `pg_stat_activity` and starts GDB attached to it.

Once GDB loads the debug symbols for `/usr/lib/postgresql/15/bin/postgres`, it will halt the process and display the `(gdb)` prompt.

### Step 4: Set a Breakpoint on Query Execution
At the GDB prompt, set a breakpoint on `exec_simple_query` (the entrypoint for plain-text SQL statements in PostgreSQL):
```text
(gdb) break exec_simple_query
(gdb) continue
```
The backend process is now running again, waiting for a command from `psql`.

### Step 5: Send a Query from psql
Go back to your **psql client terminal window** and run a simple query:
```sql
SELECT 42;
```
Press Enter. You will notice that `psql` **freezes** and does not output the result. This is because GDB has intercepted the execution and halted the backend process at our breakpoint!

### Step 6: Inspect the Intercepted Query in GDB
Go back to your **GDB terminal window**. GDB will report that the breakpoint was hit:
```text
Breakpoint 1, exec_simple_query (
    query_string=0x5608b4ea1748 "SELECT 42;") at ...
```

Now you can inspect the SQL query string directly inside the database engine's memory:
- **Print the query string argument**:
  ```text
  (gdb) print query_string
  ```
- **Inspect the call stack**:
  See how PostgreSQL navigated from receiving the query off the network sockets to the execution engine:
  ```text
  (gdb) backtrace
  ```
- **Step to the next line of code**:
  ```text
  (gdb) next
  ```
- **Resume execution**:
  ```text
  (gdb) continue
  ```

Once you run `continue`, the client backend finishes executing, and your `psql` terminal window will display the query result (`42`).
To detach and exit GDB, type `quit` (or `q`).

---

## Non-Destructive Core Capture (`gcore`)

In production databases, stopping a live process using interactive GDB is highly intrusive because it halts connection handling. Instead, you can use the `gcore` (Generate Core) tool. `gcore` attaches, writes a complete copy of the process's virtual memory space to a core dump file, and immediately detaches. The process resumes execution in milliseconds with minimal disruption.

### Step 1: Generate the Core Dump
With the `psql` connection active, run the following command in your main host terminal:
```bash
make gcore
```
This commands queries `pg_stat_activity`, extracts the PID, and runs `gcore -o /lab/postgres_backend.core <pid>` inside the container. You'll see:
```text
Saved corefile /lab/postgres_backend.core.<pid>
```

### Step 2: Locate and Analyze the Core Dump Inside the Container
Once the core dump is saved, you can open and analyze it with GDB inside the container namespace without impacting the live running PostgreSQL server.

To automatically locate the generated core file in the container's `/lab/` directory and spin up a debugging session against it:
```bash
make gcore-analyze
```
Under the hood, this Makefile target checks the container's `/lab/` directory for any generated `postgres_backend.core.<pid>` files and executes GDB against it using the PostgreSQL binary:
```bash
# Example manual command executed inside the container:
docker exec -it lab-gdb-postgres gdb /usr/lib/postgresql/15/bin/postgres /lab/postgres_backend.core.<pid>
```

Within this core analysis GDB session:
- The process status is frozen in the exact state it was in when `gcore` was triggered.
- Since it is a static memory dump, stepping commands (`next`, `step`, `continue`) are disabled.

---

## Detailed Analysis: What is inside a PostgreSQL Core Dump?

A core dump is a standard ELF (Executable and Linkable Format) file that captures a complete snapshot of the virtual memory space of the target process at the exact microsecond the dump is triggered.

### System-Level Structure of an ELF Core Dump

On Linux, a core file (usually mapped into memory as an ELF file) consists of the following sections:

1.  **ELF Header**:
    *   Identifies the file type as `ET_CORE` (Core file).
    *   Specifies target machine architecture (e.g., `x86_64`) and file offsets.
2.  **Program Header Table**:
    *   A list of descriptors pointing to memory segments (`PT_NOTE` and `PT_LOAD`) stored in the file.
3.  **`PT_NOTE` Segments (Process Metadata)**:
    *   **`NT_PRSTATUS`**: Contains CPU register states (such as instruction pointer `RIP`, stack pointer `RSP`, general-purpose registers), Process ID (`PID`), Parent Process ID (`PPID`), execution state flags, and the signal that triggered the dump (if caused by a crash).
    *   **`NT_PRPSINFO`**: Contains the command name, arguments, and process owner credentials.
    *   **`NT_AUXV` (Auxiliary Vector)**: Operating system parameter info passed from kernel to user space (e.g., page size, entry points).
    *   **`NT_FILE`**: A map showing which virtual memory ranges map to which external libraries and filesystem objects (e.g. shared object libraries like `libc.so` or `postgres` binary).
4.  **`PT_LOAD` Segments (Virtual Memory Pages)**:
    *   **Process Heap**: Dynamic memory allocated via `malloc`, `calloc`, or `brk` system calls.
    *   **Thread Stacks**: The memory stacks containing active local variables, parameters, and function call return pointers.
    *   **Global/Static variables**: Allocated memory for `.data` and `.bss` sections.
    *   **Shared Memory Segment Filter**: PostgreSQL maps a large shared memory block (for shared buffers and locks). By default, the Linux kernel coredump filter (`/proc/PID/coredump_filter`) is configured to *exclude* shared memory segments to avoid generating massive, multi-gigabyte files. Hence, the core file primarily contains the client process's private local state, heap allocations, and thread stacks (making the file size compact, around ~160MB).

---

Here is a breakdown of what you can inspect and how to interpret it inside GDB:

### 1. Intercepting the Current SQL Query & Client Connection State
Even if the query is long or complex, you can extract it and find out who sent it:
*   **Show the SQL statement**:
    ```text
    (gdb) print query_string
    ```
    This shows the exact raw query string buffer passed to `exec_simple_query`.
*   **Inspect connection socket & client credentials**:
    PostgreSQL stores connection details in a global `MyProcPort` struct of type `Port *`. You can inspect it:
    ```text
    (gdb) print *MyProcPort
    ```
    Look at the following key fields inside `MyProcPort`:
    *   `sock`: The network socket file descriptor.
    *   `remote_host`: Host IP address of the connected client.
    *   `remote_port`: Source port of the client connection.
    *   `database_name`: The database the client connected to.
    *   `user_name`: The authenticated PostgreSQL database user.

### 2. Tracing the Call Stack Hierarchy
Use `backtrace` (or `bt`) to list all active stack frames. Each line (frame) represents a function that has been called but has not yet returned:
```text
#0  exec_simple_query (query_string=0x563fc10ea538 "select 42;") at ...
#1  0x0000563f868452d9 in PostgresMain ...
```
PostgreSQL's processing stages are visible in the stack frames from bottom to top:
1.  **`main()`** & **`PostmasterMain()`**: Daemon startup and port listening.
2.  **`ServerLoop()`** & **`BackendStartup()`**: Spawning a backend child when a client connects.
3.  **`PostgresMain()`**: Loop handling client queries over the network socket.
4.  **`exec_simple_query()`**: Dispatches plain-text queries. If the query was executing, you would see frames like:
    *   `pg_parse_query()`: Lexing/parsing query string into a parse tree.
    *   `pg_analyze_and_rewrite()`: Resolving table names, types, and rewriting views.
    *   `pg_plan_queries()`: Cost-based optimizer generating execution paths.
    *   `PortalRun()` / `ExecutorRun()`: Walking the plan nodes to execute scans and joins.

To jump GDB focus to a specific frame (e.g. frame `#1` to inspect `PostgresMain` variables):
```text
(gdb) frame 1
```

### 3. Inspecting PostgreSQL Memory Contexts
PostgreSQL uses a hierarchy of custom memory pools called **Memory Contexts** (e.g., `TopMemoryContext`, `CacheMemoryContext`, `ExecutorStateContext`) to prevent memory leaks.
*   **Dump the memory context tree**:
    If the backend is stuck due to a memory issue or leak, you can execute a PostgreSQL internal utility function directly inside the GDB session to output the memory hierarchy tree:
    ```text
    (gdb) call MemoryContextStats(TopMemoryContext)
    ```
    This prints a highly detailed tree of context names, allocations, and free-list statistics to the container's standard error logs.

### 4. Analyzing Locks and IPC Wait States
If a query is hanging or slow, it may be waiting on a lock or semaphore:
*   **Inspect lock details**:
    PostgreSQL manages client lock waiting status in the shared memory `PGPROC` struct, pointed to by the global variable `MyProc`:
    ```text
    (gdb) print *MyProc
    ```
    *   Check `MyProc->links`: Identifies the queue state of the lock.
    *   Check `MyProc->waitLock`: Points to the specific `LOCK` object this backend process is blocked on.
    *   Check `MyProc->waitStatus`: Lock request status (e.g., `STATUS_WAITING` or `STATUS_OK`).
*   **Check latch/event waits**:
    Look at the stack trace. If the top frame is stuck in `WaitLatchOrSocket()` or `epoll_wait()`, the database is idle, waiting for the client to send a query, or waiting for physical disk I/O / WAL flush completion.


