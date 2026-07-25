# Getting Started with Inferno OS

Inferno should feel closer to **installing an OS with an Express path**,
not deciphering a ritual. Start simple; open the expert panels when you need them.

## Choose your path

| Path | Feels like | Time-to-shell | Command |
|------|------------|---------------|---------|
| **Express** | “Just run it” | minutes | `./try.sh` |
| **Bootable** | “Install / boot an OS” | one image build | `tools/bootable/build.sh --docker` |
| **Expert** | full control | whenever you’re ready | edit configs below |

---

## 1. Express (hosted Inferno in Docker)

This is the welcoming front door. You get a full Inferno environment
(`emu`) without touching bootloaders, subfonts, or man-page archaeology.

```bash
./try.sh                      # peerbot DENY — no host ports (safe default)
tools/peerbot/learn.sh        # short tutorial: what loco/grid/self mean
./try.sh --allow loco         # only after level 1 — 8080 on 127.0.0.1
```

What that does:

1. Builds (or reuses) the `inferno-os:dev` image
2. Starts Inferno’s window manager / emulator
3. **peerbot** keeps host ports closed; **learn.sh** unlocks nicknames in order

Learn the tree first (`ls /dev`); then learn what ports *do*; then open
**loco** / **grid** only for the test at hand. Wider opens (`--public`,
`--allow all`) stay locked until the tutorial says so.
Details: [PEERBOT.md](PEERBOT.md).

Expert overrides:

```bash
TRY_IMAGE=inferno-os:dev ./try.sh --allow loco,grid
TRY_PORTS="8080:8080" ./try.sh          # raw docker -p bypass
docker run -it --rm inferno-os:dev emu -c1 sh   # shell only
```

---

## 2. Bootable (native kernel + bootloader)

When you want Inferno as something that **actually boots**:

```bash
tools/bootable/build.sh --docker
tools/bootable/run-qemu.sh                 # peerbot DENY
tools/bootable/run-qemu.sh --allow loco    # when testing local services
```

You should see a welcome banner from `easyinit`, then a shell.

Under the hood:

```text
BIOS → PBS → 9load → plan9.ini → ieasy → easyinit → sh
```

Details: [BOOTABLE.md](BOOTABLE.md) and [tools/bootable/README.md](../tools/bootable/README.md).

### Expert panel (bootable)

| Knob | Where |
|------|--------|
| Kernel devices / embedded root | `os/pc/easy` |
| First-boot program | `os/init/easyinit.b` |
| NIC / bootfile / ports | `tools/bootable/plan9.ini` |
| QEMU graphics | `QEMU_GRAPHIC=1 tools/bootable/run-qemu.sh` |
| Classic remote-root boot | `os/pc/pc` + `wminit` (advanced) |

---

## 3. Mental model in five minutes

### Your machine is a file tree (start here)

Distributed Inferno is tough if you jump straight to it. First treat the
machine like that IDE sidebar where **CPU/GPU were just files**:

```text
ls /
ls /dev
ls /prog
ls /net
myspace          # guided tour (after hosted build)
```

Full walkthrough: **[NAMESPACE.md](NAMESPACE.md)**.

### Ports people should just know (after the tree)

| Port | Name | Role |
|------|------|------|
| **8080** | **loco** | local services on *this* machine |
| **9090** | **grid** | shared / distributed services |

Deeper map (addresses as self / host / guest): [NETWORK_PORTS.md](NETWORK_PORTS.md).

### Hosted vs native

| Mode | What runs | When to use |
|------|-----------|-------------|
| **Hosted** (`emu`) | Inferno on top of Linux/macOS/… | daily work, apps, learning |
| **Native** (`ieasy` / `ipc`) | Inferno is the kernel | bootable images, bare metal, QEMU |

Same Limbo programs; different floor underneath.

---

## 4. What about fonts, Acme, and the cryptic pages?

They still matter — later.

| Topic | Beginner stance |
|-------|-----------------|
| Fonts / subfonts | Express path ships defaults; customise after you can boot |
| Acme | wonderful editor; not required for first boot |
| Man pages | keep them; pair with these docs as the plain-language layer |
| Old grid ports (6675–6677) | still used by the Kubernetes manifests; see NETWORK_PORTS.md |

---

## 5. Where next

- Name space first: [NAMESPACE.md](NAMESPACE.md)
- Cluster on Kubernetes: [DEPLOYMENT.md](DEPLOYMENT.md)
- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Native ports / compilers: `doc/port.ms`, `INSTALL`
