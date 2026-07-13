# GDB Lab: Thread-Level Debugging in MariaDB/MySQL

## Purpose
This lab demonstrates how to inspect and debug multi-threaded server applications by attaching GDB to MariaDB (an open-source fork of MySQL).

Unlike PostgreSQL's process-per-connection model, MySQL and MariaDB use a **thread-per-connection** model. All connections are processed inside a single daemon process (`mariadbd` or `mysqld`). When a client connects, the database server either assigns an existing idle thread from the thread pool or spawns a new OS thread to handle the connection lifecycle.

---

## Hands-On Exercise: Intercepting client packets

### Step 1: Start the MariaDB Server
Start the MariaDB container in the background:
```bash
make run-server
```

### Step 2: Open a Client Session
In a **new terminal window**, connect to MariaDB via the client shell:
```bash
make mysql
```
Keep this window open. This session represents our client connection.

### Step 3: Attach GDB to the MariaDB Server Process
In your **original terminal window**, attach GDB to the main `mariadbd` daemon process:
```bash
make gdb-attach
```

Once GDB loads the symbol table for `/usr/sbin/mariadbd`, it will halt all running database execution threads and present the `(gdb)` prompt.

### Step 4: Set a Breakpoint on the Command Dispatcher
At the GDB prompt, set a breakpoint on `dispatch_command` (the function that routes incoming client SQL queries and command packets):
```text
(gdb) break dispatch_command
(gdb) continue
```
The server is now running again, waiting for input.

### Step 5: Send a Query from the MariaDB Client
Go back to your **MariaDB client terminal window** and run a simple query:
```sql
SELECT 99;
```
Press Enter. The client will **freeze** as the server thread handling this connection hits the GDB breakpoint.

### Step 6: Inspect Threads in GDB
Go back to your **GDB terminal window**. GDB will report that the breakpoint was hit:
```text
Thread 3 "mariadbd" hit Breakpoint 1, dispatch_command (
    command=COM_QUERY, thd=0x7f23c0000c08, ...
```

Since MariaDB is multi-threaded, let's explore thread debugging commands:
- **List all server threads**:
  See all active threads currently running inside the server process:
  ```text
  (gdb) info threads
  ```
  The thread marked with an asterisk `*` is the current thread that hit the breakpoint.
- **Inspect local arguments**:
  Print the query type packet argument (`command`) and the thread handler address (`thd`):
  ```text
  (gdb) print command
  (gdb) print thd->query_string
  ```
- **Show backtrace of the active thread**:
  ```text
  (gdb) backtrace
  ```
- **Resume server execution**:
  ```text
  (gdb) continue
  ```

Once you run `continue`, the client receives the server response and the `SELECT 99` output displays.
To exit GDB, type `quit` (or `q`) and confirm detaching.

---

## Non-Destructive Core Capture (`gcore`)

In multi-threaded server applications like MariaDB, stopping a running process with GDB blocks all client connections, making interactive debugging risky on active instances. The `gcore` tool can capture a full memory dump of the entire server process (including all thread states and variables) without terminating it, pausing the daemon for only a split second.

### Step 1: Generate the Core Dump
With the MariaDB container running, run the following command in your main host terminal:
```bash
make gcore
```
This commands locates the `mariadbd` server PID (which is typically PID `1` in this container namespace) and executes `gcore -o /lab/mariadb.core <pid>`. Output:
```text
Saved corefile /lab/mariadb.core.<pid>
```

### Step 2: Locate and Analyze the Core Dump Inside the Container
Once the core dump is saved, you can open and analyze it with GDB inside the container namespace without impacting the live running MariaDB server.

To automatically locate the generated core file in the container's `/lab/` directory and spin up a debugging session against it:
```bash
make gcore-analyze
```
Under the hood, this Makefile target checks the container's `/lab/` directory for any generated `mariadb.core.<pid>` files and executes GDB against it using the MariaDB server binary:
```bash
# Example manual command executed inside the container:
docker exec -it lab-gdb-mysql gdb /usr/sbin/mariadbd /lab/mariadb.core.<pid>
```

Within this core analysis GDB session:
- The process status is frozen in the exact state it was in when `gcore` was triggered.
- Since it is a static memory dump, execution/stepping commands (`next`, `step`, `continue`) are disabled.

---

## Detailed Analysis: What is inside a MariaDB Core Dump?

A core dump is a standard ELF (Executable and Linkable Format) file containing a snapshot of the virtual memory space of the target `mariadbd` process at the exact microsecond the dump was triggered.

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
    *   **`NT_AUXV` (Auxiliary Vector)**: Operating system parameter info passed from kernel to user space.
    *   **`NT_FILE`**: A map showing which virtual memory ranges map to which external libraries and filesystem objects.
4.  **`PT_LOAD` Segments (Virtual Memory Pages)**:
    *   **Process Heap**: Dynamic memory allocated via `malloc`, `calloc`, or `brk` system calls.
    *   **Thread Stacks**: The memory stacks containing active local variables, parameters, and function call return pointers for every running client thread.
    *   **Global/Static variables**: Allocated memory for `.data` and `.bss` sections.
    *   **InnoDB Buffer Pool Filter**: MariaDB maps a large shared memory block for InnoDB buffer pools. By default, the Linux kernel coredump filter (`/proc/PID/coredump_filter`) is configured to *exclude* shared memory segments to avoid generating massive, multi-gigabyte files. Hence, the core file primarily contains the client process's private local state, heap allocations, and thread stacks (making the file size compact, around ~160MB).

---

Here is a breakdown of what you can inspect and how to interpret it inside GDB:

### 1. Intercepting the Current SQL Query & Client Connection State
Unlike PostgreSQL's process-per-connection model, MariaDB uses a thread-per-connection model. Each connection is represented by a C++ class instance `THD`:
*   **Show the SQL statement**:
    Locate the `THD` object pointer and print the query string member:
    ```text
    (gdb) print thd->m_query_string
    ```
    This shows the exact raw query string buffer passed to the dispatcher.
*   **Inspect connection socket & client credentials**:
    MariaDB stores client security contexts in the `m_security_ctx` member of the `THD` class. You can inspect it:
    ```text
    (gdb) print *thd->m_security_ctx
    ```
    Look at the following key fields inside `Security_context`:
    *   `priv_user`: The authenticated username.
    *   `user`: The database user string.
    *   `host`: Host name of the connected client.
    *   `ip`: Source IP address of the client connection.

### 2. Tracing the Call Stack Hierarchy & Selecting Frames
Use `backtrace` (or `bt`) to list all active stack frames. Each line (frame) represents a function call that has been started but has not yet returned:
```text
#0  0x00007fe363039ef3 in poll (...) at ...
#1  0x0000563f8682013e in vio_read (...) at ...
#2  0x0000563f86716815 in my_real_read (...) at ...
#3  dispatch_command (command=COM_QUERY, thd=0x7f23c0000c08, packet=0x7f23c0001bc8 "SELECT 99;") at ...
#4  0x0000563f868452d9 in do_handle_one_connection ...
```

#### Understanding Frame Numbers and Local Scope
*   **Frame `#0`**: This is the function that is currently executing (where the execution pointer is right now).
*   **Frames `#1`, `#2`, `#3`, etc.**: These are the ancestor functions in the calling chain. Function `#4` called `#3`, which called `#2`, which called `#1`, which called `#0`.
*   **Local Scope Isolation**: GDB can only print local variables belonging to the *currently selected frame*. By default, when you attach to a process or load a core dump, GDB starts in **Frame `#0`**. If you try to run `print command` in Frame `#0` (which is `poll`), GDB will say:
    ```text
    No symbol "command" in current context.
    ```
    This is because `command` is only defined inside `dispatch_command`.

#### How to Switch and Select a Frame
To inspect variables defined in an outer function, you must instruct GDB to shift its local scope to that function's frame number:
1.  Look at the `bt` list and locate the frame number next to your target function (e.g. `#3` for `dispatch_command`).
2.  Switch to that frame using:
    ```text
    (gdb) frame 3
    ```
3.  Once the focus changes, you can successfully inspect the query parameters:
    ```text
    (gdb) print command
    ```

#### MariaDB Processing Flow in the Stack
MariaDB's processing stages are visible in the stack frames from bottom to top:
1.  **`mysqld_main()`**: Daemon startup and port listening.
2.  **`handle_one_connection()`**: Spawns to handle a specific client session.
3.  **`do_handle_one_connection()`**: Loops to read packets off the VIO socket.
4.  **`dispatch_command()`**: Routes command packets (e.g., `COM_QUERY`).
5.  **`mysql_parse()`**: Parsers compile SQL into an AST.
6.  **`mysql_execute_command()`**: Dispatches execution handler nodes.

### 3. Function Invocation Warning
> [!WARNING]
> **Function Invocation Requirement**: Calling function symbols (using `call` or `print` on a C++ method or function) requires GDB to temporarily hijack registers and the stack to run code in a live process namespace. This works **only when attached to a live process** (e.g., via `make gdb-attach`). If you attempt to invoke this command on a static core dump file, GDB will fail with:
> ```text
> You can't do that without a process to debug.
> ```

### 4. Finding and Listing Symbols (Variables, Arguments, and Types)
When debugging offline or in a live session, you can query GDB to discover what variables and types exist in the current scope or binary:
*   **List all local variables in the current frame**:
    ```text
    (gdb) info locals
    ```
*   **List all function arguments in the current frame**:
    ```text
    (gdb) info args
    ```
*   **Search for global or static variables matching a pattern**:
    Restrict your search using a regular expression:
    ```text
    (gdb) info variables mysqld
    ```
*   **Search for defined types and structures**:
    ```text
    (gdb) info types THD
    ```

---

## Running MariaDB/MySQL Directly under GDB (Interactive Startup)

Instead of attaching to an already running database daemon, you can launch the MariaDB server (`mariadbd`) directly inside GDB. This is useful for debugging thread-pool initialization, query execution setup, or startup routines.

### Step 1: Start MariaDB inside GDB
Stop any existing container and launch a new interactive session running GDB:
```bash
make run-gdb
```
This target starts the container in the foreground (`-it`) and launches GDB wrapping `mariadbd`, pre-configured to ignore internal signals like `SIGUSR1`, `SIGUSR2`, `SIGPIPE`, and `SIGALRM`.

GDB will load the symbols and stop at the `(gdb)` prompt.

### Step 2: Set a Breakpoint and Launch the Server
At the GDB prompt, set a breakpoint on `dispatch_command` and type `run`:
```text
(gdb) break dispatch_command
(gdb) run
```
The database daemon will start up and print its standard log output directly to the GDB console.

### Step 3: Connect and Trigger the Breakpoint
In a **new terminal window**, connect to the database:
```bash
make mysql
```
And execute a query:
```sql
SELECT 202;
```
Back in your **GDB terminal window**, you will see GDB capture the incoming connection thread and hit the breakpoint:
```text
[New Thread 0x7f23c0000c00 (LWP 54321)]
Thread 3 "mariadbd" hit Breakpoint 1, dispatch_command (command=COM_QUERY, thd=0x7f23c0000c08, ...)
(gdb) print thd->m_query_string
```
Type `continue` (or `c`) to resume and allow the query to complete.

### Step 4: Interrupt and Exit GDB
When the database is running (e.g. after typing `continue` or during startup/idle execution), the `(gdb)` prompt is inaccessible because GDB is monitoring the running server process. To stop execution and exit:
1.  In your GDB terminal, press **Ctrl+C**. This sends an interrupt signal to GDB, pausing the MariaDB/MySQL threads and restoring the active `(gdb)` prompt.
2.  Type `quit` (or `q`) and press Enter to exit. If GDB asks:
    ```text
    A debugging session is active.
        Inferior 1 [process ...] will be killed.
    Quit anyway? (y or n)
    ```
    Type `y` and press Enter. This will stop GDB and shut down the container.

---

## Cleaning Up
Once you are done with the exercise, stop and remove the container, and clean up any core dump files:
```bash
make clean
```
This stops and removes the running database container and deletes any `mariadb.core.*` files generated inside the host lab directory.


