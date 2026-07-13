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
