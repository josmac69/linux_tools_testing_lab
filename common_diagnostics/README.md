# Common Diagnostics Lab: Everyday Tests with Always-Available Tools

## Purpose
The other labs in this repository (`gdb`, `perf`, `strace`, `bpftrace`, `tcpdump`) focus on **heavy diagnostic tools** that usually require installation, elevated privileges, or containerized environments.

This lab is different. It collects the **first tests you actually run** when a Linux box misbehaves, using only tools that ship with virtually every Linux distribution — no packages to install, no Docker, no root in most cases.

The goal is to answer the four questions you ask most often, in order:

1. **Performance** — *Is the machine busy, and with what?* → [`01_performance.md`](01_performance.md)
2. **Network** — *Can it talk to the world, and who is it talking to?* → [`02_network.md`](02_network.md)
3. **Firewall** — *What traffic is being allowed or blocked?* → [`03_firewall.md`](03_firewall.md)
4. **Disk** — *Is it running out of space or drowning in I/O?* → [`04_disk.md`](04_disk.md)

---

## Design Principle: Always-Available Tools

Every command in this lab comes from one of these ubiquitous packages, present on essentially all modern distributions (Debian/Ubuntu, RHEL/Fedora, Arch, SUSE):

| Category | Package | Provides |
| --- | --- | --- |
| Core utilities | `coreutils` | `df`, `du`, `cat`, `uptime` |
| Process/memory | `procps` (`procps-ng`) | `ps`, `top`, `free`, `vmstat`, `uptime` |
| Networking | `iproute2` | `ip`, `ss` |
| Networking | `iputils` | `ping` |
| Disk/block | `util-linux` | `lsblk`, `findmnt`, `mount`, `dmesg`, `blkid` |
| Kernel interface | `/proc`, `/sys` | Live counters, no binary needed at all |

Tools that are **very common but not guaranteed** (`sar`/`iostat`/`mpstat` from `sysstat`, `smartctl` from `smartmontools`, `dig` from `dnsutils`, `traceroute`, `nftables`/`iptables`, `ufw`, `firewalld`) are clearly flagged in each document with a note on how to detect and install them.

The golden rule of this lab: **if a graphical tool isn't installed, `/proc` and `/sys` always are.** Every metric you see in `top` or `free` is just a formatted read of a kernel file you can `cat` yourself.

---

## Quick Start: One-Shot Health Check

Run a read-only snapshot across all four categories at once:

```bash
make healthcheck
# or directly:
./scripts/quick_healthcheck.sh
```

The script only **reads** state — it never changes configuration, kills processes, or writes files. It gracefully skips any tool that isn't installed and tells you so, making it safe to run on any host.

To capture the snapshot to a file for a bug report:

```bash
./scripts/quick_healthcheck.sh > /tmp/healthcheck_$(date +%Y%m%d_%H%M%S).txt 2>&1
```

---

## How to Use This Lab

Unlike the container-based labs, these tools run **directly on your host**, because their entire point is to inspect the real machine. Work through the four documents in order — each one follows the same structure:

- **What you're looking for** — the question the tool answers.
- **The command** — copy-paste ready.
- **How to read the output** — annotated example output.
- **Red flags** — the numbers that should worry you.

Start with the [Quick Health Check](scripts/quick_healthcheck.sh), then drill into whichever category the snapshot flags.
