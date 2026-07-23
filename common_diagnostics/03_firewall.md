# 03 — Firewall: What is being allowed or blocked?

Linux packet filtering happens in the kernel's **netfilter** subsystem. The confusing part is that **several front-ends drive the same underlying engine**, and which one is "the firewall" depends on the distribution. Your first job is always to find out *which front-end is in charge*.

> **Reading firewall rules requires root.** All inspection commands below need `sudo`. They only **read** state — nothing here changes a single rule.

---

## The Firewall Landscape

| Front-end | Typical on | Underlying engine | Inspect with |
| --- | --- | --- | --- |
| **`nftables`** | Debian 10+, RHEL 8+, modern default | `nf_tables` | `sudo nft list ruleset` |
| **`iptables`** | Older/LTS systems, many containers | `nf_tables` or legacy `x_tables` | `sudo iptables -L -n -v` |
| **`ufw`** | Ubuntu, Debian desktops | wraps iptables/nftables | `sudo ufw status verbose` |
| **`firewalld`** | RHEL/Fedora/CentOS | wraps nftables | `sudo firewall-cmd --list-all` |

On **Debian 13** (this lab's reference host) the native engine is **nftables**, and `iptables` is usually the `iptables-nft` compatibility shim that writes into the *same* tables. So `nft list ruleset` shows you the full truth even if rules were added via `iptables` or `ufw`.

---

## 1. Detect which front-end is active

```bash
# Is a high-level manager running?
systemctl is-active ufw firewalld 2>/dev/null

# Which binaries exist?
for t in nft iptables ufw firewall-cmd; do
    command -v "$t" >/dev/null && echo "found: $t" || echo "missing: $t"
done
```

If `ufw` or `firewalld` reports **active**, manage rules through *that* tool — editing nft/iptables directly underneath them causes confusion and gets overwritten.

> **Gotcha:** on Debian/Ubuntu the firewall binaries live in `/usr/sbin` and `/sbin`, which are **not on a normal user's `PATH`**. So `nft`/`iptables` can look "not installed" (`command not found`) when they are perfectly present. Run them with the full path or via `sudo` (root's `PATH` includes the sbin dirs), e.g. `sudo /usr/sbin/nft list ruleset`.

---

## 2. The ground truth: `nft list ruleset`

Because everything ultimately lands in netfilter, this one command shows the **complete, effective rule set** on a modern system:

```bash
sudo nft list ruleset
```

```text
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        ct state established,related accept
        iif "lo" accept
        tcp dport 22 accept
        ct state new tcp dport { 80, 443 } accept
        counter packets 194 bytes 11640 drop
    }
    chain forward { type filter hook forward priority filter; policy drop; }
    chain output { type filter hook output priority filter; policy accept; }
}
```

How to read it:

- **`policy drop`** on the `input` chain = **default-deny** (secure default): anything not explicitly accepted is dropped.
- **`ct state established,related accept`** — lets replies to connections *you* started back in. Almost every ruleset starts with this.
- **`tcp dport 22 accept`** — SSH is allowed in.
- The trailing **`counter … drop`** — the catch-all. The `packets`/`bytes` counters here tell you **how much traffic is being silently dropped** — a growing number explains those mysterious connection timeouts from [`02_network.md`](02_network.md).

---

## 3. The iptables view (legacy but everywhere)

Many systems, scripts, and containers still speak iptables. `-L` list, `-n` numeric (fast), `-v` verbose (shows counters + interfaces):

```bash
sudo iptables -L -n -v            # IPv4
sudo ip6tables -L -n -v           # IPv6 — don't forget this one
```

```text
Chain INPUT (policy DROP 12 packets, 720 bytes)
 pkts bytes target     prot opt in     out     source        destination
  980 58800 ACCEPT     all  --  lo     *       0.0.0.0/0     0.0.0.0/0
 4210  253K ACCEPT     all  --  *      *       0.0.0.0/0     0.0.0.0/0   state ESTABLISHED,RELATED
   34  2040 ACCEPT     tcp  --  *      *       0.0.0.0/0     0.0.0.0/0   tcp dpt:22
```

- **`policy DROP`** in the chain header = default-deny (good). `policy ACCEPT` with few rules = effectively **open**.
- The **`pkts`/`bytes`** columns are live counters — watch them move with `sudo iptables -L -n -v` run twice to see which rule a packet is hitting.
- A frequent gotcha: **IPv6 is a separate firewall.** A service locked down in `iptables` can still be wide open via `ip6tables`.

---

## 4. ufw — the friendly front-end (Debian/Ubuntu)

```bash
sudo ufw status verbose
```

```text
Status: active
Default: deny (incoming), allow (outgoing), disabled (routed)
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80,443/tcp                 ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

- `Status: inactive` means **ufw is not filtering anything**, regardless of configured rules.
- `Default: deny (incoming)` is the safe posture. `allow (incoming)` means the box is open unless individual rules deny.

Detect and fall back cleanly:

```bash
command -v ufw >/dev/null && sudo ufw status verbose || echo "ufw not installed"
```

---

## 5. firewalld — the RHEL/Fedora front-end

```bash
sudo firewall-cmd --state                 # running?
sudo firewall-cmd --get-active-zones      # which zone applies to which interface
sudo firewall-cmd --list-all              # rules for the default zone
```

```text
public (active)
  interfaces: eth0
  services: ssh dhcpv6-client
  ports: 8080/tcp
  ...
```

firewalld works in **zones** and **services** (named port bundles) rather than raw rules. `--list-all` for the active zone is the equivalent of "show me the effective rules."

---

## 6. Diagnosing "the firewall is blocking me"

A practical workflow:

1. **Confirm the service is even listening** — a closed port isn't a firewall problem: `ss -tulpn | grep :<port>` (from [`02_network.md`](02_network.md)).
2. **Check the default policy** — `policy drop`/`Default: deny` means the *absence* of an allow rule is the block.
3. **Watch the drop counter** — re-run `sudo nft list ruleset` (or `iptables -L -n -v`) a few seconds apart while reproducing the failure; the counter on the drop/reject rule that increments is your culprit.
4. **Check BOTH address families** — IPv4 and IPv6 rulesets are independent.
5. **Look for a logging rule** — if rules `log` before dropping, the kernel log shows the exact packets:

```bash
sudo dmesg -T | grep -i -E 'DROP|REJECT|IN=.*OUT='
journalctl -k --since "5 min ago" 2>/dev/null | grep -i -E 'DROP|REJECT'
```

---

## Cheat Sheet

| Question | Command |
| --- | --- |
| Which front-end is active? | `systemctl is-active ufw firewalld` |
| Full effective ruleset (modern)? | `sudo nft list ruleset` |
| Classic view + counters (v4/v6)? | `sudo iptables -L -n -v` / `sudo ip6tables -L -n -v` |
| ufw summary? | `sudo ufw status verbose` |
| firewalld summary? | `sudo firewall-cmd --list-all` |
| Is traffic actually being dropped? | Watch the drop-rule `counter`/`pkts` grow |
| Blocked packets in the log? | `sudo dmesg -T \| grep -i DROP` |
