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

### Step 2: Analyze the Core Dump Offline
Open the core dump offline using GDB against the MariaDB daemon binary:
```bash
# Locate your generated core file (e.g. mariadb.core.1)
# Open it in GDB against the mariadbd daemon
docker exec -it lab-gdb-mysql gdb /usr/sbin/mariadbd /lab/mariadb.core.<pid>
```

Within this core analysis GDB session:
- **Inspect all thread stacks**:
  See what every connection thread was doing at the moment of the dump:
  ```text
  (gdb) info threads
  ```
- **Inspect call stacks for all threads**:
  ```text
  (gdb) thread apply all backtrace
  ```
- **Switch to a specific thread**:
  ```text
  (gdb) thread <number>
  (gdb) backtrace
  ```
- Note that since this is an offline memory snapshot, execution commands like `step`, `next`, or `continue` will not work.

