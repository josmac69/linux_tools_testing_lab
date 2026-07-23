# 02 — Network: Can it talk, and to whom?

Modern Linux networking is driven by **`iproute2`** (`ip`, `ss`) — the tools that replaced the deprecated `ifconfig`, `netstat`, and `route`. They are installed by default everywhere. Work top-down: *interfaces → addresses → routes → DNS → reachability → sockets*.

---

## 1. Interfaces and Addresses

```bash
ip -br addr        # -br = brief, one line per interface
```

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.1.42/24 fe80::5054:ff:fe12:3456/64
wlan0            DOWN
```

- Column 2 is the **operational state**. `UP` = carrier + admin up. `DOWN` = link problem or admin-disabled. `UNKNOWN` is normal for `lo`.
- No IPv4 address on the interface you expect? → DHCP failed or static config is wrong.

```bash
ip -br link        # MAC addresses and link state without IPs
ip -s link show eth0   # -s adds RX/TX packet + error + drop counters
```

**Red flag:** non-zero and *growing* `errors` or `dropped` counters in `ip -s link` point at a bad cable, duplex mismatch, or an overwhelmed NIC.

---

## 2. Routing — where does traffic go?

```bash
ip route           # the main routing table
```

```text
default via 192.168.1.1 dev eth0 proto dhcp metric 100
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.42
```

- The **`default via …`** line is your gateway. **No default route = no internet**, full stop.
- To see which route a *specific* destination would take (invaluable for multi-homed hosts / VPNs):

```bash
ip route get 8.8.8.8
```

```text
8.8.8.8 via 192.168.1.1 dev eth0 src 192.168.1.42 uid 1000
```

---

## 3. DNS — name resolution

Resolution config and a live lookup, using only base tools:

```bash
cat /etc/resolv.conf                # which nameservers the system uses
getent hosts example.com            # resolve via the system resolver (nsswitch)
```

`getent` is part of `glibc` and is **always present**, unlike `dig`/`nslookup` (which need `dnsutils`/`bind-utils`). If `getent hosts <name>` returns nothing but `getent hosts 8.8.8.8`-style raw IPs work, you have a **DNS problem, not a connectivity problem**.

```bash
# Richer queries, only if the tool exists:
command -v dig >/dev/null && dig +short example.com || echo "dig not installed (dnsutils/bind-utils)"
```

---

## 4. Reachability — ping

```bash
ping -c 4 192.168.1.1        # gateway first (layer 3, local)
ping -c 4 8.8.8.8            # a public IP (routing + internet)
ping -c 4 example.com        # a name (adds DNS to the test)
```

This three-step ladder localises the fault:

| Works | Fails | Conclusion |
| --- | --- | --- |
| gateway | 8.8.8.8 | Routing / upstream / firewall problem |
| 8.8.8.8 | example.com | **DNS** is broken; the network is fine |
| all IPs | — but slow | Look at `time=` and packet loss % in the summary |

> Some networks and cloud security groups **block ICMP**. A failed `ping` to a host that clearly works over TCP just means ICMP is filtered — confirm with a TCP-level test below.

---

## 5. Open Ports and Live Connections — ss

`ss` (socket statistics) is the fast, modern `netstat` replacement.

```bash
ss -tulpn
```

Flag breakdown: **`t`** TCP, **`u`** UDP, **`l`** listening only, **`p`** owning process (needs root for other users' procs), **`n`** numeric (don't resolve ports to names).

```text
Netid  State    Local Address:Port   Peer Address:Port  Process
tcp    LISTEN   0.0.0.0:22           0.0.0.0:*          users:(("sshd",pid=812,fd=3))
tcp    LISTEN   127.0.0.1:5432       0.0.0.0:*          users:(("postgres",pid=1140,fd=7))
```

- **`0.0.0.0:22`** — listening on *all* interfaces (reachable from the network).
- **`127.0.0.1:5432`** — bound to loopback only (local connections only — a common, deliberate security choice for databases).

Other everyday `ss` uses:

```bash
ss -tan state established          # all established TCP connections
ss -tan state established '( dport = :443 or sport = :443 )'   # filter by port
ss -s                              # summary counts by socket type
```

**"Connection refused" vs. "timeout":** refused means something answered and *rejected* you (port closed, no listener) — a fast failure. Timeout means packets vanished silently — almost always a **firewall** dropping them ([`03_firewall.md`](03_firewall.md)).

---

## 6. A quick TCP reachability test without extra tools

`nc`/`telnet` may be absent, but **bash has a built-in `/dev/tcp`** pseudo-device:

```bash
timeout 3 bash -c 'echo > /dev/tcp/example.com/443' && echo "port 443 OPEN" || echo "port 443 closed/filtered"
```

This opens a real TCP connection and closes it immediately — the cleanest way to test a port when firewalls block ICMP `ping`.

---

## Cheat Sheet

| Question | Command |
| --- | --- |
| What are my interfaces/IPs? | `ip -br addr` |
| Link errors/drops? | `ip -s link show <iface>` |
| Do I have a gateway? | `ip route` (look for `default via`) |
| Which route to a host? | `ip route get <ip>` |
| Is DNS working? | `getent hosts <name>` |
| Is the host reachable? | `ping -c4 <ip>` (ladder: gw → 8.8.8.8 → name) |
| What's listening locally? | `ss -tulpn` |
| Who am I connected to? | `ss -tan state established` |
| Is a remote TCP port open? | `bash -c 'echo > /dev/tcp/host/port'` |
