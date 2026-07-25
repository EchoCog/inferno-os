# Network & Ports — Inferno for everyone

The goal: **every newcomer should recognise a few numbers the way
people recognise “port 80 means web”.**

Inferno’s power is that services are files you can bind and export.
Ports are just the doorways. Think of them as **sensor ↔ motor** pairs:
one side listens (sense), the other side acts (motor).

---

## Ports everyone should know

| Port | Nickname | Role | Memory hook |
|------|----------|------|-------------|
| **8080** | **loco** | Local services on this machine | “loco = local” |
| **9090** | **grid** | Shared / distributed services | “grid = go wide” |

Examples:

```text
tcp!127.0.0.1!8080     # talk to loco on myself
tcp!*!8080             # expose loco to the network (Inferno dial string)
tcp!host!9090          # reach grid on another machine
```

`try.sh` and `tools/bootable/run-qemu.sh` forward **8080** and **9090**
to the host so browser tools and peers can find you without hunting.

---

## Address roles (self / host / guest)

Plain language for the usual IP specials:

| Address | Role | Inferno-flavoured reading |
|---------|------|---------------------------|
| **127.0.0.0/8** | **self** | Inside the host’s own boundary. Loopback. “Talking to myself.” |
| **0.0.0.0** | **global host** | Bind/listen on all interfaces — **accept payloads from all guests**. |
| **255.255.255.255** | **global guest** | Broadcast — **deploy / announce to all hosts** on the local fabric. |

Sensor ↔ motor again:

- Listening on `0.0.0.0:8080` = host sensor open to guests  
- Sending to `255.255.255.255:9090` = guest motor speaking to every host  

(Exact broadcast behaviour depends on the network stack and permissions;
the metaphor is the teaching tool — use directed addresses in production.)

---

## Legacy / cluster ports (still valid)

The Kubernetes / grid manifests in this repo currently use:

| Port | Component | Protocol |
|------|-----------|----------|
| 6675 | Registry (`ndb/registry`) | Styx/9P |
| 6676 | CPU pool (`grid/cpupool`) | Styx/9P |
| 6677 | Emulator (`emu`) | Styx/9P |

Treat these as **expert / cluster internals**. New user-facing docs and
scripts prefer **8080 loco** and **9090 grid**. Over time, friendly
aliases can sit in front of the older numbers without breaking clusters.

---

## Inferno dial strings (cheat sheet)

Inferno often writes addresses as:

```text
tcp!host!port
udp!host!port
```

| Piece | Meaning |
|-------|---------|
| `tcp` | protocol |
| `host` | name, IP, `*`, or empty as allowed by the tool |
| `port` | number or service name |

Inside Inferno, once a service is mounted into your name space, you may
not need the port at all — you just `open` a path. That is the point.

---

## Config hooks in this repo

| Place | What it sets |
|-------|----------------|
| `tools/bootable/plan9.ini` | `loco=8080`, `grid=9090` for native boots |
| `try.sh` | Docker port publishes for 8080/9090 |
| `tools/bootable/run-qemu.sh` | QEMU `hostfwd` for 8080/9090 |
| `docs/DEPLOYMENT.md` | cluster ports 6675–6677 |

---

## Teaching sentence

> **8080 is loco, 9090 is grid.  
> 127/8 is self, 0.0.0.0 hosts all guests, 255.255.255.255 visits all hosts.  
> Ports are sensor–motor pairs; Inferno makes the rest look like files.**
