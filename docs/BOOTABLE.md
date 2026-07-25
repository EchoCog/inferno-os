# Bootable Inferno

How Inferno becomes a **bootable OS image**, without requiring you to
already be in the 1% who have done it before.

For the short path, see [GETTING_STARTED.md](GETTING_STARTED.md).
This page is the map under the hood.

---

## Pieces

| Piece | Source | Output |
|-------|--------|--------|
| Boot sectors | `os/boot/pc` | `mbr`, `pbs` / `pbslba` |
| Bootloader | `os/boot/pc` | `9load`, `9pxeload`, `ld.com` |
| Easy kernel | `os/pc` + `os/pc/easy` | `Inferno/386/bin/ieasy` |
| First program | `os/init/easyinit.b` | embedded as `/osinit.dis` |
| Config | `tools/bootable/plan9.ini` | read by `9load` |
| Image tool | `tools/bootable/mkfatfloppy.py` | FAT12 floppy `.img` |

---

## Boot chain

```text
BIOS
  → floppy PBS (or disk MBR → partition PBS)
    → 9load
      → plan9.ini  (bootfile=, ether0=, loco=, grid=, ...)
        → ieasy kernel
          → easyinit
            → /dis/sh.dis
```

Historical note: Inferno reuses Plan 9’s PC bootstrap (`9load`). Naming
says “Plan 9”; behaviour here boots Inferno.

---

## Why `easy` instead of classic `pc`

| Config | Init | First-boot behaviour |
|--------|------|----------------------|
| `os/pc/pc` | `wminit` | expects **bootp + remote root** |
| `os/pc/pcdisk` | `wminit` | disk devices, still remote-oriented |
| **`os/pc/easy`** | **`easyinit`** | **standalone**, friendly banner, local shell |

Classic configs are still there for experts. Newcomers get `easy`.

---

## Build

### Docker (fewest host dependencies)

```bash
tools/bootable/build.sh --docker
tools/bootable/run-qemu.sh
```

### Local hosted toolchain

Follow `INSTALL` until `Linux/386/bin/mk` exists, then:

```bash
tools/bootable/build.sh
tools/bootable/run-qemu.sh
```

### Manual steps (expert)

```bash
export PATH=$ROOT/Linux/386/bin:$PATH
(cd os/boot/pc && mk install)
(cd os/pc && mk CONF=easy install)
tools/bootable/mkbootimg.sh
```

---

## Image layouts

### Floppy (default, smallest barrier)

```text
9LOAD       bootloader
PLAN9.INI   config
IEASY       kernel
```

`tools/bootable/mkbootimg.sh --floppy` → `mkfatfloppy.py`

### Hard disk / USB-style

```text
MBR
  └─ FAT16 partition (PBS/pbslba)
        9LOAD  PLAN9.INI  IEASY
```

```bash
tools/bootable/build.sh --hd
# or, with artifacts already built:
tools/bootable/mkbootimg.sh --hd
tools/bootable/run-qemu.sh tools/bootable/dist/inferno-hd.img
```

`plan9-hd.ini` uses `bootfile=hd0!dos!ieasy`.

---

## QEMU defaults

`run-qemu.sh` uses:

- `qemu-system-i386`
- floppy boot (`-fda`)
- NIC `rtl8139` (matches `ether8139` in `os/pc/easy`)
- host forwards **8080** and **9090**
- serial console (`-nographic`) unless `QEMU_GRAPHIC=1`

---

## UEFI / modern PCs

This stack is **legacy BIOS**. Many machines and QEMU still speak it.
True UEFI boot needs a different loader story (future work).

---

## See also

- `man/10/9load` — bootstrap details
- `man/10/plan9.ini` — configuration keys
- `doc/port.ms` — hosted vs native ports
- `os/boot/README` — bootstrap models across boards
