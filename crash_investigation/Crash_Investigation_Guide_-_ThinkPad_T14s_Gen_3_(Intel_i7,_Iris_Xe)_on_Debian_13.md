# Crash Investigation Guide — ThinkPad T14s Gen 3 (Intel i7, Iris Xe) on Debian 13

**Scope:** Two crashes during work; system now boots again. Goal: extract every piece of forensic evidence from the previous boots, classify the crash type, identify the root cause, and instrument the system so the *next* crash (if any) is fully captured.

---

## 0. First: classify what kind of "crash" it was

Before running anything, recall the symptom, because it determines where evidence lives:

| Symptom | Likely class | Primary evidence location |
|---|---|---|
| Screen froze, cursor dead, no SSH response, had to hold power button | Hard hang (kernel deadlock, GPU hang, MCE) | `journalctl -b -1`, pstore, MCE logs |
| Instant black screen + reboot on its own | Kernel panic / hardware reset / thermal trip | pstore, `mcelog`/rasdaemon, ACPI/thermal logs |
| Instant power-off (no reboot) | Thermal emergency shutdown, battery/power fault, EC intervention | Last lines of `journalctl -b -1`, thermal logs, EC/BIOS event log |
| Session restarted, back at login screen | Userspace crash (compositor/Xorg/Wayland), **not** kernel | `coredumpctl`, display manager logs |
| Freeze but music kept playing / SysRq worked | GPU hang (i915) with display dead but kernel alive | i915 error state, journal |

A "crash" that only kills the graphical session is a completely different investigation from a kernel panic. The commands below cover both, but keep this triage in mind while reading output.

---

## 1. Check whether you even have persistent logs

Debian 13 defaults to persistent journald, but verify — everything in sections 2–4 depends on it:

```bash
ls -ld /var/log/journal/
journalctl --list-boots
```

**What to look for:**
- `--list-boots` must show multiple entries (`-2`, `-1`, `0` = current). If only boot `0` exists, the journal is volatile and evidence from the crashes is gone — jump to section 10 (instrumentation) and section 5–8 (hardware state, which survives).
- Note the timestamps of boots `-1` and `-2`. The *end* timestamp of each previous boot ≈ moment of crash. Compare against when you remember the machine dying — if the journal's last entry is minutes *before* the crash, the machine died too fast to flush logs (typical of hard hangs / instant power loss), which is itself diagnostic.

If journal is not persistent, enable it now:

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

---

## 2. Autopsy of the previous boots

### 2.1 The last minutes before death

```bash
# Everything from the boot that crashed, errors and worse:
journalctl -b -1 -p err --no-pager

# The final 200 lines of the crashed boot — the most important output of the whole investigation:
journalctl -b -1 -n 200 --no-pager

# Same for the boot before that (the first crash):
journalctl -b -2 -p err --no-pager
journalctl -b -2 -n 200 --no-pager

# Kernel-only view (dmesg of the dead boot):
journalctl -b -1 -k --no-pager
```

**What to look for in the tail of the dead boot:**

- **Abrupt silence.** Normal shutdown ends with `systemd-shutdown`, `Reached target Power-Off`, journal stop messages. If the log just *stops* mid-activity with no shutdown sequence → hard hang, panic, or power cut. This is the single most telling signal.
- **`kernel: BUG:`, `kernel: Oops:`, `general protection fault`, `unable to handle page fault`** → kernel bug; note the stack trace and which module is on top (e.g. `i915`, `iwlwifi`, `nvme`, `thunderbolt`).
- **`Fixing recursive fault`, `watchdog: BUG: soft lockup — CPU#N stuck`, `rcu: INFO: rcu_preempt detected stalls`** → CPU stuck in kernel; note which CPU (on Alder Lake, CPUs 0–7 with HT are P-cores, higher numbers are E-cores — a pattern isolated to one core type is meaningful).
- **`mce: [Hardware Error]`, `Machine check events logged`** → hardware fault (CPU, cache, memory controller, bus). Go straight to section 5.
- **`i915 0000:00:02.0: [drm] GPU HANG`, `Resetting chip for stopped heartbeat`, `GuC firmware ... failed`** → GPU hang; section 6.
- **`thermal thermal_zone*: critical temperature reached`, `shutting down`** → thermal emergency; section 7.
- **`nvme nvme0: controller is down`, `I/O error`, `EXT4-fs error`, filesystem remounted read-only** → storage dropped out; section 8.
- **`iwlwifi ... Microcode SW error detected`, `Fseq Registers`** followed by instability → Intel AX211 firmware crash; usually recoverable but known to occasionally wedge the whole machine on this platform.
- **ACPI errors, `AE_NOT_FOUND`, EC timeouts** shortly before death → firmware/EC problem; section 9.

### 2.2 Was it actually a userspace crash?

```bash
# All recorded coredumps, with timestamps:
coredumpctl list

# Detail + backtrace of a specific crash near the incident time:
coredumpctl info <PID-or-match>
```

**What to look for:** Coredumps of `gnome-shell`, `kwin_wayland`, `Xorg`, `Xwayland`, or your compositor at the crash timestamps mean the *session* died, not the kernel. Frequent compositor crashes on this hardware very often trace back to Mesa/i915 — cross-check with section 6. Coredumps of random unrelated apps at various times can instead point to failing RAM (section 5.3).

### 2.3 Pattern across boots

```bash
# Count of unclean shutdowns — every boot that starts with a filesystem recovery journal replay:
journalctl -k | grep -iE "recovering journal|orphan_cleanup|unclean"

# Timeline of all boots with duration:
journalctl --list-boots --no-pager
```

Two crashes close together after a period of stability suggests a recent change: kernel update, firmware update, new peripheral, hot weather, docking-station change. Check:

```bash
grep -E " install | upgrade " /var/log/dpkg.log | tail -50
# Specifically kernel and firmware:
grep -E "linux-image|firmware|intel-microcode|mesa" /var/log/dpkg.log | tail -30
```

---

## 3. pstore — the kernel's black box

On this machine (UEFI), a panicking kernel can write its final console output into EFI variables (`efi-pstore`). This survives power loss and is the *only* record when the crash was too fast for journald.

```bash
ls -la /sys/fs/pstore/
sudo cat /sys/fs/pstore/dmesg-efi-* 2>/dev/null | less
# Debian may also archive collected records here:
ls -la /var/lib/systemd/pstore/
```

**What to look for:**
- Files named `dmesg-efi-<timestamp>` — each is a chunk of the panic console output. Read them in order; the panic reason and stack trace are here.
- If `/sys/fs/pstore` is empty and the module isn't loaded: `sudo modprobe efi_pstore` and check again, and verify `cat /sys/module/kernel/parameters/crash_kexec_post_notifiers` and that `printk` to pstore is enabled. Empty pstore + abruptly-cut journal + no MCE log strongly suggests **power/EC-level cut or hard freeze without panic** (thermal trip, EC, PSU/battery) rather than a kernel panic — the kernel never got to say anything.

---

## 4. Full crash dumps for next time (kdump)

If pstore had nothing and the journal cut off silently, set up kdump so a future panic produces a full vmcore:

```bash
sudo apt install kdump-tools
# Debian will add crashkernel= to the kernel cmdline; verify after reboot:
cat /proc/cmdline | grep crashkernel
cat /sys/kernel/kexec_crash_loaded    # must be 1
```

Dumps land in `/var/crash/`. Analyze with `crash` + the matching `linux-image-*-dbg` package. This is overkill for a one-off, but with two crashes already, it's justified.

Also enable panic-on-hang behaviors so hangs *become* capturable panics:

```bash
# Temporarily:
sudo sysctl kernel.softlockup_panic=1 kernel.hung_task_panic=1 kernel.panic=30
# Persist in /etc/sysctl.d/99-crashdebug.conf if the problem continues.
```

---

## 5. Hardware error channels

### 5.1 Machine Check Exceptions (CPU/memory-controller faults)

```bash
sudo apt install rasdaemon
sudo systemctl enable --now rasdaemon
# Historical events already in the journal:
journalctl -k -b -1 | grep -iE "mce|machine check|hardware error"
# Once rasdaemon runs:
sudo ras-mc-ctl --summary
sudo ras-mc-ctl --errors
```

**What to look for:** Any MCE is significant. Decode the bank: cache errors and internal-parity errors on a mobile Alder Lake i7 that recur → CPU degradation or unstable voltage/thermals; memory-controller read errors → LPDDR5 issue (soldered on the T14s — a confirmed RAM fault means mainboard replacement, so you want certainty before concluding that). One-off corrected errors under heat can be noise; repeated or *uncorrected* ones are not.

### 5.2 PCIe / AER errors

```bash
journalctl -b -1 -k | grep -iE "aer|pcieport|corrected error|uncorrect"
```

**What to look for:** Repeated corrected errors on the NVMe or WiFi root port suggest signal-integrity or ASPM problems — a classic cause of hard hangs on ThinkPads. If present, test with `pcie_aspm=off` on the kernel cmdline (section 11).

### 5.3 Memory test (do this — it's cheap and rules out the worst case)

The T14s Gen 3 has soldered LPDDR5, so a RAM fault is a mainboard fault. Rule it out:

```bash
# Quick in-OS smoke test (leave ~2 GB for the OS; adjust to your RAM size):
sudo apt install memtester
sudo memtester 12G 2
```

Then, more seriously: reboot into **memtest86+** (Debian package `memtest86+` adds a GRUB entry; note that on UEFI you need the recent memtest86+ 6/7.x which supports EFI) and let it run at least one full pass, ideally overnight.

**What to look for:** *Any* error is a fail. Also note that in-OS memtester passing does not clear the suspect — errors often appear only when the memory controller is hot; run memtest86+ after a warm gaming/compile session if possible.

---

## 6. GPU — i915 / Iris Xe (a prime suspect on this exact machine)

Alder Lake-P Iris Xe under Linux has a well-documented history of GPU hangs, PSR (Panel Self Refresh) glitches, and GuC/HuC firmware issues that can present as full-system freezes.

```bash
# GPU hangs recorded in the dead boots:
journalctl -b -1 -k | grep -iE "i915|drm|gpu hang|guc|huc|reset"
journalctl -b -2 -k | grep -iE "i915|drm|gpu hang|guc|huc|reset"

# If a hang happened in the *current* boot, the error state is dumpable:
sudo cat /sys/class/drm/card*/error 2>/dev/null | head -100

# Firmware & driver state:
sudo dmesg | grep -iE "guc|huc|dmc"
glxinfo -B 2>/dev/null | grep -E "OpenGL renderer|Mesa"
```

**What to look for:**
- `GPU HANG: ecode 12:...`, `Resetting chip for stopped heartbeat on rcs0` — engine hangs. If the reset succeeds you get a stutter; if it fails, the machine freezes. Note *which engine* (rcs0 = render, vcs = video decode — vcs hangs implicate hardware video decoding in the browser).
- `GuC firmware load failed`, DMC firmware messages — make sure `firmware-misc-nonfree` is current; outdated GuC firmware on ADL-P caused exactly these hangs.
- PSR-related messages (`PSR2`, `Panel Self Refresh`) combined with freezes where the *display* dies but Magic SysRq still works → test with `i915.enable_psr=0` on the kernel cmdline. This is one of the most common T14s Gen 3 Intel stability fixes.
- If GPU is the suspect, mitigation ladder: (1) update `firmware-misc-nonfree` + Mesa, (2) `i915.enable_psr=0`, (3) `i915.enable_dc=0`, (4) `i915.enable_guc=0` — apply one at a time so you know which one helped.

---

## 7. Thermal and power

The T14s is thin; sustained load can hit thermal limits, and a critical trip point produces an *instant, logless* power-off.

```bash
# Thermal events in the dead boots:
journalctl -b -1 | grep -iE "thermal|critical temperature|throttl"

# Current sensor inventory and trip points:
sudo apt install lm-sensors
sudo sensors-detect --auto
sensors
grep . /sys/class/thermal/thermal_zone*/type /sys/class/thermal/thermal_zone*/temp
grep . /sys/class/thermal/thermal_zone*/trip_point_*_{type,temp} 2>/dev/null

# Was the CPU being throttled before death?
journalctl -b -1 -k | grep -iE "core temperature above threshold|package temperature"

# Reproduce under observation:
sudo apt install stress-ng s-tui
s-tui   # run a stress test while watching temps live
```

**What to look for:**
- `critical temperature reached (…), shutting down` in the dead boot → confirmed thermal shutdown. On a 3–4 year old T14s the usual physical causes are dust in the fan/fin stack and degraded thermal paste.
- During `s-tui`/`stress-ng`: package temps pinned at 95–100 °C with the fan audibly struggling, or an idle temperature noticeably higher than ~45 °C, points to a cooling problem.
- Fan behavior: `sensors` should show the fan RPM (thinkpad_acpi). A fan stuck at low RPM under load = EC/fan fault.
- Also check the power side: crashes only on battery vs. only on AC vs. only on a USB-C dock is a crucial pattern. Dock/charger negotiation faults (buggy USB-C PD firmware) are a known cause of instant power cuts on ThinkPads.

---

## 8. Storage (NVMe)

A dying or power-state-buggy NVMe drive causes freezes where the system hangs on any disk I/O.

```bash
sudo apt install smartmontools nvme-cli
sudo smartctl -a /dev/nvme0
sudo nvme smart-log /dev/nvme0
sudo nvme error-log /dev/nvme0

# Filesystem damage from the crashes:
journalctl -b 0 -k | grep -iE "ext4|recovering|orphan"
sudo dmesg | grep -iE "nvme|blk_update|I/O error"
```

**What to look for:**
- SMART: `Media and Data Integrity Errors` > 0, `Percentage Used` near 100, `Critical Warning` ≠ 0x00, growing `Error Information Log Entries`.
- Journal of dead boots: `nvme nvme0: controller is down; will reset`, `Device not ready; aborting reset` — controller dropouts, frequently caused by aggressive APST power states on certain SSD models. Mitigation to test: `nvme_core.default_ps_max_latency_us=0` on the kernel cmdline.
- After two hard crashes, run a read-only fsck check at next opportunity (`sudo touch /forcefsck` or fsck from a live USB) — journal replay usually handles it, but verify.

---

## 9. Firmware, BIOS, and platform

```bash
# Current firmware versions:
sudo dmidecode -s bios-version && sudo dmidecode -s bios-release-date
fwupdmgr get-devices
fwupdmgr refresh && fwupdmgr get-updates

# CPU microcode status:
dmesg | grep microcode
dpkg -l intel-microcode

# ACPI/EC complaints in the dead boots:
journalctl -b -1 -k | grep -iE "acpi|\bec\b|AE_"

# Suspend/resume correlation — did a crash follow a resume?
journalctl -b -1 | grep -iE "suspend|resume|s2idle|systemd-sleep"
```

**What to look for:**
- **Outdated BIOS/EC.** Lenovo shipped many stability-relevant UEFI/EC updates for the T14s Gen 3 Intel (21BR/21BS), several explicitly addressing hangs and USB-C/dock issues. The machine supports firmware updates directly via `fwupdmgr update` (LVFS) — this is genuinely one of the highest-probability fixes and should be done regardless of what else you find.
- `intel-microcode` installed and loaded (`dmesg | grep microcode` shows an updated revision at early boot). Missing microcode on Alder Lake is a real stability risk.
- Crashes occurring shortly *after resume from suspend*: this platform uses s2idle (`cat /sys/power/mem_sleep` — expect `[s2idle]`), and broken s2idle wake paths (often GPU or WiFi related) are a classic T14s failure mode. If both crashes were post-resume, that's your pattern.
- Also check Lenovo's BIOS event log from firmware setup (F1 at boot) — thermal and EC events are sometimes recorded there and nowhere else.

---

## 10. Instrument the system for the next crash

Do all of these now, so a third crash is fully captured:

```bash
# 1. Persistent journal with synchronous flushing of critical messages (default OK, verify):
sudo mkdir -p /var/log/journal && sudo systemctl restart systemd-journald

# 2. Enable Magic SysRq so you can distinguish "kernel alive" from "kernel dead" during a freeze:
echo 'kernel.sysrq=1' | sudo tee /etc/sysctl.d/90-sysrq.conf
sudo sysctl --system
```

**During the next freeze**, try **Alt+SysRq(PrtSc)+ t** — if the display is dead but this dumps tasks (visible in journal after reboot), the kernel was alive → GPU/display problem. If nothing reacts, try the recovery/diagnosis sequence Alt+SysRq + **r e i s u b** — if even `s` (sync) does nothing, the kernel is dead → panic/hardware.

```bash
# 3. rasdaemon running (section 5.1), kdump configured (section 4).

# 4. Continuous sensor logging so the last recorded temperature before a crash is known:
sudo apt install sysstat
sudo systemctl enable --now sysstat
# and a lightweight temp logger:
( while true; do echo "$(date -Is) $(cat /sys/class/thermal/thermal_zone*/temp | tr '\n' ' ')"; sleep 10; done ) \
  | sudo tee -a /var/log/temp-trace.log &
# (turn this into a small systemd service if the investigation runs for days)
```

Optionally, if you have a second machine on the LAN: **netconsole** streams kernel messages over UDP in real time and captures panic output that never reaches disk:

```bash
sudo modprobe netconsole netconsole=6665@<this-laptop-ip>/<iface>,6666@<receiver-ip>/<receiver-mac>
# On the receiver: nc -u -l 6666
```

---

## 11. Decision tree / interpretation summary

| Evidence found | Conclusion | Next action |
|---|---|---|
| Panic trace in pstore or journal naming `i915` | GPU driver/firmware | Update firmware-misc-nonfree + Mesa; try `i915.enable_psr=0` |
| `GPU HANG` messages, session died but SysRq worked | GPU hang, kernel survived | Same as above; check browser HW video decode (vcs engine) |
| MCE events | Hardware: CPU/cache/memory controller | Check cooling first; if MCEs persist when cool → warranty/board |
| `critical temperature reached` | Thermal shutdown | Clean fan/fins, repaste; verify with s-tui |
| memtest86+ errors | Soldered RAM fault | Mainboard replacement (warranty check) |
| NVMe controller resets / SMART errors | SSD | `nvme_core.default_ps_max_latency_us=0` test; replace SSD if SMART bad |
| Journal cuts silently, pstore empty, SysRq dead, no MCE | EC/power-level cut or hard platform hang | BIOS/EC update via fwupd; test without dock/USB-C peripherals; check AC vs battery pattern |
| Both crashes shortly after resume | s2idle wake path | BIOS update; test with `i915.enable_psr=0`; check `iwlwifi` errors around resume |
| Compositor coredumps only, kernel logs clean | Userspace/graphics stack | Update Mesa; report to Debian with `coredumpctl info` backtrace |
| Recent kernel/firmware upgrade right before crashes | Regression | Boot previous kernel from GRUB and observe |

**Kernel cmdline test parameters** (add in `/etc/default/grub` → `GRUB_CMDLINE_LINUX_DEFAULT`, then `sudo update-grub`; apply *one at a time*):

- `i915.enable_psr=0` — panel self-refresh off (most common Iris Xe stability fix)
- `i915.enable_dc=0` — display power-saving states off
- `nvme_core.default_ps_max_latency_us=0` — NVMe APST off
- `pcie_aspm=off` — PCIe link power management off
- `intel_idle.max_cstate=2` — limit CPU C-states (diagnoses deep-idle instability; costs battery)

---

## 12. Suggested order of execution

1. `journalctl --list-boots` → confirm evidence exists (§1)
2. Read the tails of boots `-1` and `-2` (§2.1) — 10 minutes, likely tells you the crash class
3. Check pstore (§3) and coredumps (§2.2)
4. Grep the dead boots for the specific subsystems: mce, i915, thermal, nvme, acpi (§5–9)
5. `fwupdmgr get-updates` → apply BIOS/EC updates (§9) — do this regardless
6. Install rasdaemon, enable SysRq, start temp logging, configure kdump (§10)
7. Stress test under observation: `s-tui` + `stress-ng --cpu 8 --gpu` equivalents, memtest86+ overnight (§5.3, §7)
8. If a suspect emerged, apply the single matching mitigation from §11 and observe
