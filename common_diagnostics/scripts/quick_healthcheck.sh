#!/usr/bin/env bash
#
# quick_healthcheck.sh — a read-only, always-available Linux diagnostics snapshot.
#
# Covers the four categories of the Common Diagnostics Lab:
#   performance, network, firewall, disk
#
# Design rules:
#   * READ ONLY. It never changes configuration, kills processes, or writes files.
#   * Uses only tools shipping with virtually every distro (coreutils, procps,
#     iproute2, iputils, util-linux) plus /proc & /sys.
#   * Any tool that is not installed is skipped with a clear note — never fatal.
#   * Firewall inspection needs root; if not root, it says so and moves on.
#
# Usage:
#   ./quick_healthcheck.sh                 # print to terminal
#   ./quick_healthcheck.sh > report.txt    # capture for a bug report
#
# Intentionally NOT using `set -e`: a missing optional tool must not abort the run.
set -uo pipefail

# Firewall/admin tools (nft, iptables, ...) live in /usr/sbin & /sbin, which are
# NOT on a normal user's PATH on Debian/Ubuntu. Add them so detection works for
# both root and unprivileged runs. This is itself a common real-world gotcha:
# "command not found" for a tool that is actually installed.
export PATH="$PATH:/usr/sbin:/sbin:/usr/local/sbin"

# --- tiny presentation helpers ------------------------------------------------

section() {
    printf '\n\033[1;36m==== %s ====\033[0m\n' "$1"
}

sub() {
    printf '\n\033[1;33m--- %s ---\033[0m\n' "$1"
}

# have <cmd>: true if the command exists in PATH
have() { command -v "$1" >/dev/null 2>&1; }

# run_if <cmd> -- <command line...>: run only if <cmd> exists, else note it.
run_if() {
    local probe="$1"; shift
    [ "$1" = "--" ] && shift
    if have "$probe"; then
        "$@"
    else
        printf '  (skipped: "%s" not installed)\n' "$probe"
    fi
}

# --- header -------------------------------------------------------------------

printf '\033[1;32mLinux Quick Health Check\033[0m\n'
printf 'Host    : %s\n' "$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null)"
printf 'Kernel  : %s\n' "$(uname -srmo 2>/dev/null || uname -a)"
printf 'Uptime  : %s\n' "$(uptime -p 2>/dev/null || uptime)"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    printf 'Distro  : %s\n' "$(. /etc/os-release; echo "${PRETTY_NAME:-unknown}")"
fi
printf 'User    : %s (uid=%s)\n' "$(id -un 2>/dev/null)" "$(id -u 2>/dev/null)"

# =============================================================================
section "1. PERFORMANCE"
# =============================================================================

sub "Load average vs. CPU count"
cpus="$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo '?')"
printf 'Logical CPUs: %s\n' "$cpus"
cat /proc/loadavg 2>/dev/null

sub "CPU / memory / IO sample (vmstat 1 x3)"
run_if vmstat -- vmstat 1 3

sub "Memory"
run_if free -- free -h

sub "Top 5 processes by CPU"
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -n 6

sub "Top 5 processes by memory"
ps -eo pid,user,%cpu,%mem,rss,comm --sort=-%mem 2>/dev/null | head -n 6

sub "Recent OOM-killer activity (kernel log)"
if have dmesg && dmesg -T >/dev/null 2>&1; then
    if dmesg -T 2>/dev/null | grep -i -E 'out of memory|oom-kill|killed process' | tail -n 5 | grep -q .; then
        dmesg -T 2>/dev/null | grep -i -E 'out of memory|oom-kill|killed process' | tail -n 5
    else
        echo "  none found"
    fi
else
    echo "  (dmesg not readable without root; try: sudo dmesg -T | grep -i oom)"
fi

# =============================================================================
section "2. NETWORK"
# =============================================================================

sub "Interfaces & addresses"
if have ip; then
    ip -br addr 2>/dev/null
else
    echo "  (skipped: iproute2 'ip' not installed — unusual)"
    cat /proc/net/dev 2>/dev/null
fi

sub "Default route(s)"
if have ip; then
    ip route show default 2>/dev/null || echo "  (no default route!)"
    total_routes="$(ip route 2>/dev/null | wc -l)"
    printf '  (%s routes total in the main table; full list: ip route)\n' "$total_routes"
else
    echo "  (skipped: iproute2 'ip' not installed)"
fi

sub "DNS configuration"
[ -r /etc/resolv.conf ] && grep -E '^\s*nameserver' /etc/resolv.conf 2>/dev/null || echo "  (no /etc/resolv.conf nameservers)"

sub "Listening TCP/UDP sockets"
if have ss; then
    ss -tulpn 2>/dev/null | head -n 20
else
    run_if netstat -- netstat -tulpn
fi

sub "Established connection count"
if have ss; then
    printf 'Established TCP connections: %s\n' "$(ss -tan state established 2>/dev/null | grep -c -v '^State')"
fi

sub "Gateway reachability (ping, best-effort)"
gw="$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')"
if [ -n "${gw:-}" ] && have ping; then
    ping -c 2 -W 2 "$gw" 2>/dev/null | tail -n 3 || echo "  gateway $gw did not respond (ICMP may be filtered)"
else
    echo "  (no default gateway found, or ping unavailable)"
fi

# =============================================================================
section "3. FIREWALL"
# =============================================================================

sub "Front-end detection"
for t in nft iptables ip6tables ufw firewall-cmd; do
    if have "$t"; then printf '  found:   %s\n' "$t"; else printf '  missing: %s\n' "$t"; fi
done
if have systemctl; then
    printf '  managers active: %s\n' "$(systemctl is-active ufw firewalld 2>/dev/null | paste -sd' ' - 2>/dev/null)"
fi

if [ "$(id -u 2>/dev/null)" != "0" ]; then
    echo
    echo "  Firewall rules require root — re-run with sudo to see the ruleset:"
    echo "     sudo $0"
else
    if have ufw && ufw status 2>/dev/null | grep -qi 'Status: active'; then
        sub "ufw status (active)"; ufw status verbose 2>/dev/null
    elif have firewall-cmd && firewall-cmd --state 2>/dev/null | grep -qi running; then
        sub "firewalld (running)"; firewall-cmd --list-all 2>/dev/null
    elif have nft; then
        sub "nftables ruleset"
        if nft list ruleset 2>/dev/null | grep -q .; then
            nft list ruleset 2>/dev/null
        else
            echo "  (empty nftables ruleset — checking iptables)"
            run_if iptables -- iptables -L -n -v
        fi
    else
        run_if iptables -- iptables -L -n -v
    fi
fi

# =============================================================================
section "4. DISK"
# =============================================================================

sub "Filesystem space usage"
df -hT 2>/dev/null | grep -v -E '^(tmpfs|devtmpfs|overlay|udev)' || df -h 2>/dev/null

sub "Inode usage"
df -i 2>/dev/null | grep -v -E '^(tmpfs|devtmpfs|overlay|udev)'

sub "Block device / mount layout"
if have lsblk; then
    lsblk -f 2>/dev/null
else
    cat /proc/mounts 2>/dev/null
fi

sub "Filesystems mounted read-only (possible corruption)"
# Only real block-device filesystems matter here. Pseudo/ramfs mounts such as
# squashfs snaps and /run/credentials/* are read-only BY DESIGN — excluding them
# avoids false alarms.
if have findmnt; then
    ro="$(findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS 2>/dev/null | \
        awk '$1 ~ /^\/dev\// && $4 ~ /(^|,)ro(,|$)/ {print "  "$2"  ("$3")"}')"
    [ -n "$ro" ] && printf '%s\n' "$ro" || echo "  none"
else
    awk '$1 ~ /^\/dev\// && $4 ~ /(^|,)ro(,|$)/ {print "  "$2}' /proc/mounts 2>/dev/null | grep . || echo "  none (from /proc/mounts)"
fi

sub "I/O bottleneck check (iostat, optional)"
run_if iostat -- iostat -xz 1 2

sub "Disk I/O errors in kernel log"
if have dmesg && dmesg -T >/dev/null 2>&1; then
    dmesg -T 2>/dev/null | grep -i -E 'I/O error|EXT4-fs error|XFS.*error|remount.*read-only' | tail -n 5 | grep -q . \
        && dmesg -T 2>/dev/null | grep -i -E 'I/O error|EXT4-fs error|XFS.*error|remount.*read-only' | tail -n 5 \
        || echo "  none found"
else
    echo "  (dmesg not readable without root)"
fi

printf '\n\033[1;32mHealth check complete.\033[0m See common_diagnostics/*.md to interpret any red flags.\n'
