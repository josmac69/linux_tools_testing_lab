# Tcpdump Lab: Network Packet Capturer

## Purpose
`tcpdump` is a command-line packet analyzer. It allows you to sniff network traffic flowing through a network interface in real time, filtering packets based on criteria (IP addresses, ports, protocols) via Berkeley Packet Filters (BPF). 

It sees the **wire-level reality**—exactly what was transmitted over the physical or virtual interface—not what a high-level application framework claims was sent.

---

## Technical Concept: Shared Network Namespaces
Normally, sniffing network traffic on the host requires root access to control network interfaces in promiscuous mode. 
In Docker, containers have isolated network namespaces. However, Docker allows a container to run in the network namespace of another service using `network_mode: "service:<name>"`.

In this lab:
- `web-server` runs on port 8080.
- `client` requests pages from `web-server:8080`.
- `sniffer` is attached directly to `web-server`'s network interface.
- By running `tcpdump` inside `sniffer`, we capture all packets entering and leaving the `web-server` container on port 8080.

---

## Lab Architecture
Because the network namespace is isolated to our micro-network, we do not require host-level root credentials or risk exposing host network packets.

---

## Navigation & Execution Commands

### 1. Start the Capture Stack
To compile the sniffer image and launch the server, client, and sniffer simultaneously:
```bash
make run
```

### 2. Interpreting the Packet Output
In the log stream, you will see recurring blocks of TCP packets representing curl requests:

```text
IP 172.19.0.3.43522 > 172.19.0.2.8080: Flags [S], seq 342211902, ...
IP 172.19.0.2.8080 > 172.19.0.3.43522: Flags [S.], seq 988771120, ack 342211903, ...
IP 172.19.0.3.43522 > 172.19.0.2.8080: Flags [.], ack 1, ...
IP 172.19.0.3.43522 > 172.19.0.2.8080: Flags [P.], seq 1:82, ack 1, ...
```

- **`172.19.0.3.43522 > 172.19.0.2.8080`**: Source IP and Port -> Destination IP and Port.
- **`Flags [S]`**: SYN packet (initiates connection).
- **`Flags [S.]`**: SYN-ACK packet (response from server).
- **`Flags [.]`**: ACK packet (acknowledgment of connection established—completing the **TCP 3-way handshake**).
- **`Flags [P.]`**: PUSH-ACK packet (transmitting application data, i.e., the HTTP GET request).

### 3. Tear Down the Stack
Once done, press **`Ctrl+C`** in the terminal to stop the containers, and run:
```bash
make clean
```
to delete the containers and virtual networks.
