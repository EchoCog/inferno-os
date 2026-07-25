# Inferno OS

Inferno® is a distributed operating system, originally developed at Bell Labs,
now Free Software. Applications written in Limbo compile to portable Dis
bytecode and run anywhere Inferno’s environment is available — hosted on
another OS, or **native** with its own kernel and bootloader.

> **New here?** Start with the Express path. You should not need cryptic man
> pages, font lore, or Acme muscle-memory just to try the system.

## Try it (Express path)

```bash
./try.sh                 # safe default: no host ports published
./try.sh --allow loco    # open 8080 on loopback when you need it
```

That builds (once) and runs hosted Inferno in Docker. **peerbot** keeps
ports closed until you opt in by nickname (loco / grid / …).

Plain-language guide: **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**  
Name space first (devices as files): **[docs/NAMESPACE.md](docs/NAMESPACE.md)**  
Port conscience (default deny): **[docs/PEERBOT.md](docs/PEERBOT.md)**  
Port map everyone should know: **[docs/NETWORK_PORTS.md](docs/NETWORK_PORTS.md)**

## Bootable image (native kernel + bootloader)

```bash
tools/bootable/build.sh --docker
tools/bootable/run-qemu.sh

# Larger disk image (MBR + FAT16):
tools/bootable/build.sh --docker --hd   # also built in Dockerfile.bootable
tools/bootable/run-qemu.sh tools/bootable/dist/inferno-hd.img
```

Produces a QEMU-bootable image (`9load` → `ieasy` → friendly shell).
First lesson after boot: `ls /dev` — your machine is a file tree.
Details: [docs/BOOTABLE.md](docs/BOOTABLE.md) · [tools/bootable/](tools/bootable/)

| Nickname | Port | Meaning |
|----------|------|---------|
| **loco** | **8080** | local services on this machine |
| **grid** | **9090** | shared / distributed services |

## Cluster deployment

Inferno can also run as a distributed cluster on Kubernetes (registry, CPU
pool, emulator as microservices).

**Docker images:**
```bash
docker build -t inferno-os:dev .
docker build -f Dockerfile.production -t inferno-os:latest .
```

**Kubernetes (Kustomize):**
```bash
kustomize build k8s/overlay/staging | kubectl apply -f -
kustomize build k8s/overlay/production | kubectl apply -f -
```

**Helm:**
```bash
helm install inferno helm/inferno-cluster --namespace inferno --create-namespace
```

| Service | Component | Port | Protocol |
|---------|-----------|------|----------|
| Registry | `ndb/registry` | 6675 | Styx/9P |
| CPU Pool | `grid/cpupool` | 6676 | Styx/9P |
| Emulator | `emu` | 6677 | Styx/9P |

(Cluster-internal ports above; day-to-day loco/grid are 8080/9090.)

### Cluster docs

- [Getting Started](docs/GETTING_STARTED.md) — Express / Bootable / Expert
- [Name Space](docs/NAMESPACE.md) — devices & processes as files (before “distributed”)
- [Network & Ports](docs/NETWORK_PORTS.md) — loco, grid, self/host/guest
- [Bootable Inferno](docs/BOOTABLE.md) — bootloader, kernel, QEMU image
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Kubernetes Reference](docs/KUBERNETES.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Operations](docs/OPERATIONS.md)
- [Monitoring](docs/MONITORING.md)

### CI/CD

GitHub Actions (`.github/workflows/build-deploy.yml`) builds, tests, and can
deploy staging/production.

## Building from source

See [`INSTALL`](INSTALL) for the hosted toolchain. Native kernels live under
`os/` (PC port: `os/pc`, bootstrap: `os/boot/pc`).

---

Inferno represents services and resources in a file-like name hierarchy.
Programs access them with open/read/write/close. A single file-service
protocol (9P/Styx) makes resources importable and exportable across the
network — the same idea whether you started from `./try.sh` or a bootable image.
