# Bootable Inferno (accessible path)

This directory turns Inferno’s native PC pieces into something you can
**build once and boot**, without memorising cryptic man pages first.

## What you get

| Artifact | Role |
|----------|------|
| `9load` + `pbs` | Bootloader (Plan 9 / Inferno BIOS chain) |
| `ieasy` | Standalone “easy” kernel + friendly `easyinit` |
| `plan9.ini` | Sensible QEMU defaults (expert-editable) |
| `inferno-boot.img` | 1.44MB FAT floppy image you can boot in QEMU |

Boot chain:

```text
BIOS → PBS → 9load → plan9.ini → ieasy → easyinit → shell
```

## Quick commands

```bash
# One-shot via Docker (recommended if you do not have a hosted build yet)
tools/bootable/build.sh --docker
tools/bootable/run-qemu.sh                 # peerbot DENY — no hostfwd
tools/bootable/run-qemu.sh --allow loco    # open 8080 on loopback when testing

# Hard-disk style image (MBR + FAT16 partition)
tools/bootable/build.sh --docker --hd
tools/bootable/run-qemu.sh tools/bootable/dist/inferno-hd.img

# Or, with a local hosted toolchain already installed:
tools/bootable/build.sh
tools/bootable/build.sh --hd
tools/bootable/run-qemu.sh
```

After boot, ignore “distributed” for a minute:

```text
ls /dev
ls /prog
cat /dev/sysname
```

That IDE feeling — devices as files in the tree — *is* the model.
See `docs/NAMESPACE.md`.

## Expert knobs

| Env / file | Purpose |
|------------|---------|
| `tools/bootable/plan9.ini` | NIC, bootfile, loco/grid port conventions |
| `INFERNO_KERNEL=` | Alternate kernel path for `mkbootimg.sh` |
| `QEMU_GRAPHIC=1` | VGA window instead of serial console |
| `QEMU_EXTRA=...` | Extra QEMU arguments |
| `os/pc/easy` | Kernel device / root file list |

## Why “easy” exists

The historical `pc` + `wminit` path expects **bootp + a remote file server**.
That is powerful — and a brutal first experience.

`easy` + `easyinit` boot **standalone**: local devices, embedded root,
welcome banner, and the port map (`8080` loco / `9090` grid).

## Related docs

- [Getting Started](../../docs/GETTING_STARTED.md)
- [Network & ports](../../docs/NETWORK_PORTS.md)
- [Bootable deep dive](../../docs/BOOTABLE.md)
