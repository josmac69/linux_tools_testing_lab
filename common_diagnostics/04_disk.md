# 04 — Disk: Out of space, or drowning in I/O?

"Disk problems" are two completely different failures that get confused constantly:

- **Capacity** — you've run out of *space* (bytes) or *inodes* (file slots). Static; a snapshot answers it.
- **Performance** — the disk is *slow* under load (throughput/latency). Dynamic; needs sampling over time.

Diagnose capacity first (it's instant and a frequent root cause), then performance.

---

## 1. Space — df

```bash
df -h          # human-readable sizes
df -hT         # -T also shows the filesystem type
```

```text
Filesystem      Type   Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  ext4   234G  198G   24G  90% /
tmpfs           tmpfs  7.9G  1.2M  7.9G   1% /run
/dev/nvme0n1p1  vfat   511M  6.1M  505M   2% /boot/efi
```

- **`Use%`** is the headline. Above ~90% on `/` is a warning; some filesystems reserve 5% for root, so 100% can hit non-root users early.
- Watch for surprises: a full **`/boot`** breaks kernel upgrades; a full **`tmpfs`** on `/tmp` or `/run` breaks running services even when `/` has room.

### The inode trap

A disk can be **0% full of data yet 100% full of inodes** — millions of tiny files (mail spools, session caches, PID dirs). `df` reports plenty of space, but writes fail with *"No space left on device"*.

```bash
df -i          # -i shows INODE usage, not bytes
```

If `IUse%` is at 100% while `Use%` is low, you've found it — hunt the directory with the file count, not the byte count.

---

## 2. What's eating the space — du

`df` says *the disk is full*; `du` says *where*. Find the biggest directories under a path:

```bash
# Top-level breakdown of the current filesystem, largest last
sudo du -h -x --max-depth=1 / 2>/dev/null | sort -h | tail -n 15
```

- **`-x`** — stay on one filesystem; without it, `du` wanders into `/proc`, `/sys`, network mounts, and other disks.
- **`--max-depth=1`** — summarise per top-level dir; drill deeper by pointing `du` at the biggest hit and repeating.
- **`2>/dev/null`** — hide permission-denied noise.

Common culprits to check directly: `/var/log` (runaway logs), `/var/lib/docker` (images/volumes), `/var/cache`, and home directories.

> **Deleted-but-open files:** if `df` shows a full disk but `du` can't find the space, a process is still holding a deleted file open (classic with rotated logs). Find it with:
> ```bash
> sudo lsof +L1 2>/dev/null | grep -i deleted    # lsof: util-linux/lsof, usually present
> ```
> Restarting the offending process releases the space.

---

## 3. Block devices and mounts — lsblk / findmnt

```bash
lsblk -f       # -f adds filesystem type, label, UUID, and mountpoint
```

```text
NAME        FSTYPE FSVER LABEL UUID                                 MOUNTPOINTS
nvme0n1
├─nvme0n1p1 vfat   FAT32       A1B2-C3D4                            /boot/efi
└─nvme0n1p2 ext4   1.0         3f9a...e1                            /
```

This is the tree of physical disks → partitions → filesystems → where they're mounted. An unmounted partition (blank `MOUNTPOINTS`) that you *expected* mounted is a red flag.

```bash
findmnt                        # every mount as a readable tree
findmnt /                      # details for one mount (source, fs, options)
cat /proc/mounts               # the raw kernel truth, always available
```

Mount options matter: **`ro`** in the options means the filesystem was **remounted read-only** — the kernel does this when it detects corruption. Confirm with `dmesg`:

```bash
sudo dmesg -T 2>/dev/null | grep -i -E 'ext4|xfs|btrfs|I/O error|remount|read-only'
```

---

## 4. I/O performance — is the disk the bottleneck?

Recall from [`01_performance.md`](01_performance.md): high **`wa`** (I/O wait) in `vmstat`, or processes stuck in **`b`** (blocked), points here.

### Always-available: /proc/diskstats

Even with **zero extra packages**, the kernel exposes per-device I/O counters. `vmstat` already summarises them:

```bash
vmstat 1 5          # watch 'bi' (blocks in/read) and 'bo' (blocks out/written)
```

Sustained high `bi`/`bo` with high `wa` = the workload is I/O-bound.

### Better: iostat (optional, `sysstat`)

```bash
command -v iostat >/dev/null && iostat -xz 1 3 || echo "sysstat not installed"
```

```text
Device   r/s   w/s   rkB/s   wkB/s  await  aqu-sz  %util
nvme0n1  12.0  340.0  480.0  54400.0  8.20   2.90   96.4
```

The two columns that matter:

- **`%util`** — how busy the device is. **Near 100% = saturated.** (Note: on SSDs/NVMe with internal parallelism, 100% `%util` doesn't always mean maxed out, but it's still your best single signal.)
- **`await`** — average ms per I/O request (queue + service time). Single-digit ms is healthy for SSD; tens-to-hundreds of ms means the device is struggling.

Install for the richer view:

```bash
sudo apt install sysstat      # Debian/Ubuntu
sudo dnf install sysstat      # RHEL/Fedora
```

---

## 5. Drive health — SMART (optional, `smartmontools`)

Failing hardware shows up as I/O errors in `dmesg` and rising reallocated-sector counts long before total death.

```bash
command -v smartctl >/dev/null && sudo smartctl -H /dev/nvme0n1 || echo "smartmontools not installed"
sudo smartctl -a /dev/sda     # full attribute dump for SATA/SAS
```

Watch `SMART overall-health` (`PASSED`/`FAILED`) and, on spinning disks, `Reallocated_Sector_Ct` and `Current_Pending_Sector` — non-zero and *growing* means the drive is dying. Back up now.

---

## Cheat Sheet

| Question | Command |
| --- | --- |
| Is a filesystem full (bytes)? | `df -h` → **`Use%`** |
| Out of inodes (tiny files)? | `df -i` → **`IUse%`** |
| What's eating the space? | `sudo du -h -x --max-depth=1 <path> \| sort -h \| tail` |
| Space gone but `du` can't find it? | `sudo lsof +L1 \| grep deleted` |
| Disk/partition/mount layout? | `lsblk -f`, `findmnt` |
| Filesystem gone read-only? | `findmnt` options + `dmesg \| grep -i 'read-only'` |
| Is I/O the bottleneck? | `vmstat 1` (`wa`, `bi`, `bo`) or `iostat -xz 1` |
| Is the drive dying? | `sudo smartctl -H <dev>` + `dmesg \| grep -i 'I/O error'` |
