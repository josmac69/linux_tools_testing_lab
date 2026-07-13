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
