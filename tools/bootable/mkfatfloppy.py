#!/usr/bin/env python3
"""
Create an Inferno/Plan 9 style bootable FAT12 floppy image.

Faithful enough to utils/format (floppy -f -d -b PBS) that 9load can
boot from the resulting image under QEMU or on real BIOS hardware.

Usage:
  mkfatfloppy.py -o inferno-boot.img [-b pbs] file[=DOSNAME] ...
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
import time
from pathlib import Path


# 3½HD geometry (same as utils/format/format.c)
BYTES = 512
SECTORS = 18
HEADS = 2
TRACKS = 80
MEDIA = 0xF0
CLUSTER = 1
VOLSECS = SECTORS * HEADS * TRACKS  # 2880
IMGSIZE = VOLSECS * BYTES  # 1_474_560


def putshort(v: int) -> bytes:
    return struct.pack("<H", v & 0xFFFF)


def putlong(v: int) -> bytes:
    return struct.pack("<I", v & 0xFFFFFFFF)


def dos83(name: str) -> tuple[bytes, bytes]:
    """Split a basename into 8.3 DOS name parts."""
    base = Path(name).name.upper()
    if "." in base:
        stem, ext = base.rsplit(".", 1)
    else:
        stem, ext = base, ""
    stem = stem.replace(" ", "")[:8].ljust(8)
    ext = ext.replace(" ", "")[:3].ljust(3)
    return stem.encode("ascii", "replace"), ext.encode("ascii", "replace")


class Fat12Image:
    def __init__(self, label: str = "INFERNO"):
        self.label = (label.upper() + "           ")[:11]
        self.clustersize = CLUSTER
        self.fatbits = 12
        # Match format.c heuristics for 1.44MB
        self.fatsecs = (self.fatbits * (IMGSIZE // (BYTES * self.clustersize)) + 8 * BYTES - 1) // (
            8 * BYTES
        )
        self.rootsecs = VOLSECS // 200
        self.rootfiles = self.rootsecs * (BYTES // 32)
        self.img = bytearray(IMGSIZE)
        self.fat = bytearray(self.fatsecs * BYTES)
        self.root = bytearray(self.rootsecs * BYTES)
        self.fat[0] = MEDIA
        self.fat[1] = 0xFF
        self.fat[2] = 0xFF
        self.fatlast = 1
        self.root_next = 0
        self.data_off = BYTES + 2 * self.fatsecs * BYTES + self.rootsecs * BYTES

    def clustalloc(self, flag: str) -> int:
        """flag: 'sof' | 'mid' | 'eof' — mirrors format.c Sof/Eof."""
        if flag != "sof":
            x = 0xFFF if flag == "eof" else (self.fatlast + 1)
            x &= 0xFFF
            o = (3 * self.fatlast) // 2
            if self.fatlast & 1:
                self.fat[o] = (self.fat[o] & 0x0F) | ((x << 4) & 0xF0)
                self.fat[o + 1] = (x >> 4) & 0xFF
            else:
                self.fat[o] = x & 0xFF
                self.fat[o + 1] = (self.fat[o + 1] & 0xF0) | ((x >> 8) & 0x0F)
        if flag == "eof":
            return 0
        self.fatlast += 1
        return self.fatlast

    def write_boot_sector(self, pbs: bytes | None) -> None:
        buf = bytearray(BYTES)
        if pbs:
            buf[:] = pbs[:BYTES].ljust(BYTES, b"\0")
        else:
            # Minimal non-Inferno stub; real boots should pass -b pbs
            buf[0:3] = b"\xEB\x3C\x90"
            buf[0x1FE:0x200] = b"\x55\xAA"

        # Force JMP + BPB the way format.c does after loading PBS
        buf[0:3] = b"\xEB\x3C\x90"
        buf[3:11] = b"Plan9.00"
        buf[11:13] = putshort(BYTES)
        buf[13] = self.clustersize
        buf[14:16] = putshort(1)  # reserved
        buf[16] = 2  # fats
        buf[17:19] = putshort(self.rootfiles)
        buf[19:21] = putshort(VOLSECS)
        buf[21] = MEDIA
        buf[22:24] = putshort(self.fatsecs)
        buf[24:26] = putshort(SECTORS)
        buf[26:28] = putshort(HEADS)
        buf[28:32] = putlong(0)  # hidden
        buf[32:36] = putlong(VOLSECS)
        buf[36] = 0  # drive
        buf[38] = 0x29  # bootsig
        buf[39:43] = putlong(int(time.time()) & 0xFFFFFFFF)
        buf[43:54] = self.label.encode("ascii")
        buf[54:62] = b"FAT12   "
        buf[0x1FE] = 0x55
        buf[0x1FF] = 0xAA
        self.img[0:BYTES] = buf

    def add_file(self, src: Path, dosname: str | None = None) -> None:
        data = src.read_bytes()
        name = dosname or src.name
        stem, ext = dos83(name)

        start = 0
        if data:
            nclust = (len(data) + BYTES * self.clustersize - 1) // (BYTES * self.clustersize)
            padded = data + b"\0" * (nclust * BYTES * self.clustersize - len(data))
            start = self.clustalloc("sof")
            for i in range(nclust - 1):
                self.clustalloc("mid")
            self.clustalloc("eof")
            # cluster 2 is first data cluster; fatlast started at 1
            # After sof, fatlast==2 for first file's first cluster
            file_off = self.data_off + (start - 2) * BYTES * self.clustersize
            end = file_off + len(padded)
            if end > len(self.img):
                raise SystemExit(f"image full; cannot add {src}")
            self.img[file_off:end] = padded

        if self.root_next >= self.rootfiles:
            raise SystemExit("root directory full")
        ent = bytearray(32)
        ent[0:8] = stem
        ent[8:11] = ext
        ent[11] = 0x20  # archive
        # crude timestamp
        ent[22:24] = putshort(0)
        ent[24:26] = putshort(0)
        ent[26:28] = putshort(start)
        ent[28:32] = putlong(len(data))
        off = self.root_next * 32
        self.root[off : off + 32] = ent
        self.root_next += 1
        print(f"  + {name:12}  {len(data):8} bytes  <- {src}")

    def finalize(self) -> bytes:
        # FAT #1, FAT #2, root
        o = BYTES
        self.img[o : o + len(self.fat)] = self.fat
        o += len(self.fat)
        self.img[o : o + len(self.fat)] = self.fat
        o += len(self.fat)
        self.img[o : o + len(self.root)] = self.root
        return bytes(self.img)


def parse_file_arg(arg: str) -> tuple[Path, str | None]:
    if "=" in arg:
        path_s, dos = arg.split("=", 1)
        return Path(path_s), dos
    return Path(arg), None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-o", "--output", required=True, help="output image path")
    ap.add_argument("-b", "--boot", help="PBS boot sector (Inferno/386/pbs)")
    ap.add_argument("-l", "--label", default="INFERNO", help="volume label")
    ap.add_argument(
        "files",
        nargs="+",
        help="files to add; optional DOS name via path=NAME.EXT",
    )
    args = ap.parse_args()

    pbs = None
    if args.boot:
        pbs = Path(args.boot).read_bytes()
        if len(pbs) < 512:
            print(f"warning: PBS {args.boot} is only {len(pbs)} bytes", file=sys.stderr)

    img = Fat12Image(label=args.label)
    img.write_boot_sector(pbs)

    print(f"Formatting FAT12 3½HD image ({IMGSIZE} bytes)")
    for farg in args.files:
        path, dos = parse_file_arg(farg)
        if not path.is_file():
            raise SystemExit(f"missing file: {path}")
        img.add_file(path, dos)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(img.finalize())
    print(f"Wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
