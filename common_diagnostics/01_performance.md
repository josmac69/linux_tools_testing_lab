# 01 — Performance: Is the machine busy, and with what?

The question splits into three resources: **CPU**, **memory**, and **load**. The classic diagnostic order is *load average → CPU breakdown → memory → the offending process*.

---

## 1. Load Average — the 10-second overview

```bash
uptime
```

```text
 14:32:07 up 6 days,  3:14,  2 users,  load average: 0.82, 1.95, 3.10
```

- The three numbers are the **run-queue length** averaged over **1, 5, and 15 minutes** (runnable + uninterruptible-sleep tasks).
- **Rule of thumb:** compare to your CPU count. `nproc` tells you how many cores you have.
  - `load == nproc` → fully utilised, no queue.
  - `load > nproc` → tasks are waiting; the system is oversubscribed.
- **Trend matters more than the value:** `0.82, 1.95, 3.10` means load is *falling* (the 1-min figure is lowest). Rising figures (`3.10, 1.95, 0.82`) mean a problem is *building*.

```bash
nproc                    # number of logical CPUs
cat /proc/loadavg        # same load, plus running/total tasks and last PID
```

> A high load average with **low CPU usage** usually means processes are stuck in **uninterruptible sleep (D state)** — almost always disk or network I/O. Jump to [`04_disk.md`](04_disk.md).

---

## 2. CPU Breakdown — where the cycles go

```bash
vmstat 1 5      # 5 samples, one second apart
```

```text
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 2  0      0 512340  84120 2103400    0    0     3    12  210  480 12  3 84  1  0
 5  1      0 498120  84120 2103400    0    0     0  1840  920 3100 61 18  6 15  0
```

Read the **first row as a since-boot average, then ignore it**; the following rows are live. Key columns:

- **`r`** — processes waiting for CPU. Persistently `> nproc` = CPU-bound.
- **`b`** — processes blocked on I/O. Persistently `> 0` = I/O-bound.
- **`us` / `sy`** — % time in user vs. kernel (system) code. High `sy` often means heavy syscall/context-switch traffic (see [`../strace/README.md`](../strace/README.md)).
- **`wa`** — % time CPUs sat idle **waiting for I/O**. High `wa` points at disk.
- **`st`** — "stolen" time; on a VM, `st > 0` means the hypervisor gave your CPU to someone else.
- **`si` / `so`** — swap in/out. Anything **consistently non-zero here is a red flag** (see memory below).

---

## 3. Live Process View — top

```bash
top             # interactive; press 'q' to quit
```

Useful in-session keys:

- **`P`** — sort by CPU (default), **`M`** — sort by memory.
- **`1`** — expand per-core CPU lines.
- **`e`** — cycle memory units (K/M/G).
- **`H`** — toggle showing individual threads.

For a **non-interactive, scriptable** snapshot (great for logs and this repo's healthcheck):

```bash
# Top 10 CPU consumers
ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu | head -n 11

# Top 10 memory consumers
ps -eo pid,ppid,user,%cpu,%mem,rss,comm --sort=-%mem | head -n 11
```

`rss` is **resident set size in KB** — actual physical RAM the process holds.

---

## 4. Memory — free, and the meaning of "free"

```bash
free -h
```

```text
               total        used        free      shared  buff/cache   available
Mem:            15Gi       4.2Gi       512Mi       320Mi        10Gi        10Gi
Swap:          2.0Gi          0B       2.0Gi
```

The single most misread table in Linux. The number that matters is **`available`**, not `free`:

- **`free`** — RAM doing literally nothing. On a healthy long-running box this is *supposed* to be small.
- **`buff/cache`** — RAM used for the page cache and buffers. It's **reclaimable** — the kernel hands it back the instant an application needs it.
- **`available`** — the kernel's estimate of how much a new process could get **without swapping**. This is your real headroom.

**Red flags:**
- `available` near zero → genuine memory pressure.
- `Swap … used` climbing while `available` is low → the system is swapping to survive; expect latency spikes.
- Check whether the **OOM killer** has fired recently:

```bash
dmesg -T 2>/dev/null | grep -i -E 'out of memory|oom-kill|killed process'
journalctl -k -b 2>/dev/null | grep -i 'oom'    # if systemd/journald present
```

---

## 5. Per-CPU and richer stats (optional: `sysstat`)

`mpstat`, `iostat`, and `sar` give per-core and historical data but come from the **`sysstat`** package, which is common but **not guaranteed**.

```bash
command -v mpstat >/dev/null && mpstat -P ALL 1 3 || echo "sysstat not installed"
```

Install if you want it:

```bash
# Debian/Ubuntu
sudo apt install sysstat
# RHEL/Fedora
sudo dnf install sysstat
```

When it's missing, you lose nothing critical — everything above works with `procps` alone.

---

## Cheat Sheet

| Question | Command |
| --- | --- |
| Is the box overloaded right now? | `uptime` + `nproc` |
| CPU vs. I/O bound? | `vmstat 1 5` (watch `r`, `b`, `wa`) |
| Who is eating the CPU? | `ps -eo pid,%cpu,comm --sort=-%cpu \| head` |
| Who is eating RAM? | `ps -eo pid,%mem,rss,comm --sort=-%mem \| head` |
| Real free memory? | `free -h` → **`available`** column |
| Are we swapping? | `vmstat 1` → `si`/`so`, or `free -h` swap row |
| Did OOM killer fire? | `dmesg -T \| grep -i oom` |
