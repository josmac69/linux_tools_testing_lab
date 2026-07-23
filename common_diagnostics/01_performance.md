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

## 5. Richer and historical stats — the `sysstat` package

`mpstat`, `iostat`, and `sar` all ship in the **`sysstat`** package. It's on almost every server but is **not guaranteed** on a minimal install, so detect before use:

```bash
command -v sar >/dev/null && echo "sysstat present" || echo "sysstat not installed"
```

Install it:

```bash
# Debian/Ubuntu
sudo apt install sysstat
# RHEL/Fedora
sudo dnf install sysstat
```

The everyday tools above (`uptime`, `vmstat`, `ps`, `free`) all read a **single instant** or a short live sample. What `sysstat` adds is two things they can't give you: **per-resource breakdowns** (per-CPU, per-device) and — uniquely for `sar` — **history**, so you can answer *"what was the box doing at 3 a.m. when it paged?"* after the fact.

### 5.1 `mpstat` — per-CPU breakdown

`vmstat` averages all cores into one `us`/`sy`/`id`/`wa` line. `mpstat -P ALL` splits it **per logical CPU**, which is how you catch a single saturated core hiding behind a low overall average:

```bash
mpstat -P ALL 1 3      # all CPUs, 1-second samples, 3 times
```

```text
07:15:22  CPU   %usr  %nice  %sys %iowait  %irq  %soft %steal  %idle
07:15:23  all   9.02   0.00  2.51    0.25  0.00   0.30   0.00  87.92
07:15:23    0  95.05   0.00  4.95    0.00  0.00   0.00   0.00   0.00
07:15:23    1   1.01   0.00  0.00    0.00  0.00   0.00   0.00  98.99
```

- Here the `all` line looks idle (**87.9% idle**), but **CPU 0 is pinned at 100%** — a classic single-threaded bottleneck. `vmstat`/`uptime` would never show this.
- **`%iowait`** — this CPU was idle waiting for I/O (per-core version of `vmstat`'s `wa`).
- **`%irq` / `%soft`** — time servicing hardware / software interrupts. High `%soft` on one CPU often means all NIC interrupts land on a single core (poor IRQ affinity).
- **`%steal`** — on a VM, cycles the hypervisor gave to another guest.

Use it whenever the load average is high but overall CPU% looks fine — the work is probably concentrated on one or two cores.

### 5.2 `iostat` — per-device disk throughput and latency

Covered in depth in [`04_disk.md`](04_disk.md), but it belongs to the same package. The extended form is what you want:

```bash
iostat -xz 1 3         # -x extended metrics, -z hide idle devices, 1s x3
```

The two decisive columns are **`%util`** (how busy the device is — near 100% = saturated) and **`await`** (average ms per I/O request). `iostat` also prints a top CPU-summary line each interval, so it doubles as a quick CPU+disk combined view. See [`04_disk.md`](04_disk.md#4-io-performance--is-the-disk-the-bottleneck) for full column-by-column reading.

### 5.3 `sar` — the system activity **recorder** (the important one)

`sar` (System Activity Reporter) is the most valuable and least-known tool here. Its superpower is **history**: a background collector samples the system every few minutes and stores the data on disk, so `sar` can replay *any* metric from *earlier today* — or, with daily archives, from previous days. This is the difference between diagnosing a 3 a.m. incident and shrugging at it.

**How the recording works.** Installing `sysstat` sets up a collector that must be *enabled*:

```bash
# Debian/Ubuntu: switch the collector on
sudo sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
sudo systemctl enable --now sysstat        # or: sysstat.service / the cron job
```

- A cron entry (`/etc/cron.d/sysstat`) runs `sa1` every ~10 minutes to append a sample.
- Data lands in **`/var/log/sysstat/saDD`** (or `/var/log/sa/saDD`), one binary file per day of the month (`DD`). Files rotate monthly, so `sa23` is the 23rd's data.
- `sar` reads today's file **by default**; point it at an old file to read history.

**Reading live data** (works even without the collector — it just samples on the spot):

```bash
sar 1 3            # overall CPU, 1-second interval, 3 samples
```

```text
07:20:01  CPU  %user  %nice  %system  %iowait  %steal  %idle
07:20:02  all   6.12   0.00     1.53     0.51    0.00   91.84
Average:  all   5.98   0.00     1.60     0.48    0.00   91.94
```

**Reading history** — this is the point. With no interval, `sar` prints *today's recorded samples* from the archive:

```bash
sar                       # today's CPU history, every collection interval
sar -q                    # load average & run-queue history
sar -r                    # memory (used/free/cache/commit) history
sar -S                    # swap-space utilisation history
sar -W                    # swapping rate (pages in/out per second) history
sar -b                    # overall I/O rate history
sar -d -p                 # per-device I/O history (-p = pretty device names)
sar -n DEV                # per-interface network throughput history
sar -n TCP,ETCP           # TCP connection & error-rate history
sar -B                    # paging stats (page faults, page-in/out) history
sar -u ALL -P ALL         # per-CPU history, all fields
```

**Zoom into a time window** with `-s`/`-e` (start/end, `HH:MM:SS`) — e.g. *what did memory and swap look like during the 03:00–03:30 slowdown?*

```bash
sar -r -s 03:00:00 -e 03:30:00
```

**Read a previous day** by pointing at its archive file (`-f`). To inspect the 15th:

```bash
sar -q -f /var/log/sysstat/sa15                 # Debian/Ubuntu path
sar -r -f /var/log/sa/sa15 -s 03:00:00 -e 03:30:00   # RHEL path, memory, 03:00–03:30
```

**Combine flags** to correlate resources at the same timestamps — the fastest way to prove *what* was starved:

```bash
sar -u -r -b -s 02:45:00 -e 03:15:00 -f /var/log/sysstat/sa15
#   CPU + memory + I/O, side by side, for that half hour on the 15th
```

**Why `sar` beats `vmstat` for incident review:**

| | `vmstat`/`top`/`free` | `sar` |
| --- | --- | --- |
| Time covered | now, or while you watch | **the whole day, retroactively** |
| Granularity | one merged view | CPU, mem, swap, I/O, net — each separately |
| After an incident | nothing to see; it's over | replay the exact minutes it happened |
| Cost | run on demand | tiny background collector |

> **Rule of thumb:** on any server you care about, enable the `sysstat` collector *before* you need it. When a "the site was slow at 3 a.m." ticket lands, `sar -s 02:45 -e 03:15` turns guesswork into a timeline.

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
| One core pinned, rest idle? | `mpstat -P ALL 1 3` *(sysstat)* |
| Per-device disk load? | `iostat -xz 1 3` *(sysstat)* |
| **What happened at 3 a.m.?** | `sar -s 02:45:00 -e 03:15:00 -f /var/log/sysstat/saDD` *(sysstat)* |
| Historical memory/swap? | `sar -r` / `sar -S` / `sar -W` *(sysstat)* |
| Historical CPU / load? | `sar` / `sar -q` *(sysstat)* |
