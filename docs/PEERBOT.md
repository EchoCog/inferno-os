# peerbot — default-deny ports for people still learning

You should not need a CCNA (or a scar from minikube) to try Inferno.

**peerbot** is a tiny “port conscience” for the Express and Bootable paths.
Inspired by the same instinct as PeerBlock-style tools and by real accidents:

- “minikube went public with my entire filesystem”
- “I pushed a shallow clone and LFS ate itself”
- “I have no idea which ports are open”

Rule:

> **Block all host port publishes unless there is a good reason  
> for what we are currently testing.**

---

## Default

```bash
./try.sh
tools/bootable/run-qemu.sh
```

- **No** `-p` publishes  
- **No** QEMU `hostfwd`  
- Traffic stays inside the container/VM (**self** boundary)

Perfect for the first lesson: `ls /dev`, `ls /prog`  
([NAMESPACE.md](NAMESPACE.md)).

---

## Open only what this test needs

```bash
./try.sh --allow loco              # 8080 on 127.0.0.1
./try.sh --allow loco,grid         # 8080 + 9090 on loopback
./try.sh --allow loco --public     # 0.0.0.0 — you meant "global host"

tools/bootable/run-qemu.sh --allow grid
```

| Nickname | Port | Good reason to open |
|----------|------|---------------------|
| **loco** | 8080 | testing local services on this machine |
| **grid** | 9090 | testing shared / discovery fabric |
| registry / cpupool / emulator | 6675–6677 | expert cluster debugging |
| metrics | 9100 | validating monitoring scrapes |

Full catalog: `tools/peerbot/ports.catalog`  
Inspect: `tools/peerbot/peerbot.sh list` / `why loco`

---

## Bind address = how loud you are

| Mode | Bind | Meaning |
|------|------|---------|
| default | `127.0.0.1` | **self** — only your host’s loopback |
| `--public` / `PEERBOT_PUBLIC=1` | `0.0.0.0` | **global host** — accept guests on all interfaces |

peerbot will print which one it is using. Prefer loopback until a real peer
needs to call in.

---

## How it fits the rest of the map

- Ports as sensor↔motor: [NETWORK_PORTS.md](NETWORK_PORTS.md)
- Tree before grid: [NAMESPACE.md](NAMESPACE.md)
- Cluster Services still expose loco/grid **aliases**; peerbot governs
  what your **laptop** publishes when you try Inferno locally.

Kubernetes NetworkPolicies in this repo are the cluster-side cousin:
default-deny ingress, then allow the ports the service actually needs.

---

## Expert overrides

```bash
TRY_PORTS="8080:8080 9090:9090" ./try.sh    # bypass nicknames
PEERBOT_ALLOW=loco ./try.sh                 # env default
QEMU_EXTRA=... tools/bootable/run-qemu.sh   # raw qemu knobs
```

If you bypass peerbot, you own the blast radius — that is fine, as long as
it is intentional.

---

## Teaching sentence

> **Closed until proven necessary.  
> Open by nickname for this test.  
> Loopback first; 0.0.0.0 only when guests must arrive.**
