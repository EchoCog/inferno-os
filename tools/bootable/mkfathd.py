#!/usr/bin/env python3
"""
Create a bootable hard-disk image for Inferno (MBR + FAT16 partition).

Layout:
  sector 0          MBR (Inferno mbr preferred)
  sector PART_LBA   partition PBS/BPB (Inferno pbslba or pbs)
  ...               FAT16 with 9LOAD, PLAN9.INI, IEASY

Usage:
  mkfathd.py -o inferno-hd.img -m mbr -b pbslba file[=DOSNAME] ...
"""

from __future__ import annotations

import argparse
import struct
import sys
import time
from pathlib import Path

SECTOR = 512
PART_LBA = 63  # classic first-track alignment; widely BIOS-friendly
DEFAULT_MB = 64


def putshort(v: int) -> bytes:
    return struct.pack("<H", v & 0xFFFF)


def putlong(v: int) -> bytes:
    return struct.pack("<I", v & 0xFFFFFFFF)


def dos83(name: str) -> tuple[bytes, bytes]:
    base = Path(name).name.upper()
    if "." in base:
        stem, ext = base.rsplit(".", 1)
    else:
        stem, ext = base, ""
    return stem.replace(" ", "")[:8].ljust(8).encode("ascii", "replace"), ext.replace(
        " ", ""
    )[:3].ljust(3).encode("ascii", "replace")


def chs(lba: int, heads: int = 255, spt: int = 63) -> tuple[int, int, int]:
    """Approximate CHS for partition table (LBA is what modern BIOS uses)."""
    c = lba // (heads * spt)
    r = lba % (heads * spt)
    h = r // spt
    s = r % spt + 1
    if c > 1023:
        c, h, s = 1023, heads - 1, spt
    return c, h, s


def pack_chs(c: int, h: int, s: int) -> bytes:
    return bytes([h & 0xFF, (s & 0x3F) | ((c >> 2) & 0xC0), c & 0xFF])


class Fat16Partition:
    def __init__(self, nsectors: int, label: str = "INFERNO"):
        self.nsectors = nsectors
        self.label = (label.upper() + "           ")[:11]
        self.bytes_per_sec = SECTOR
        self.sec_per_clust = 4
        self.reserved = 1
        self.nfats = 2
        self.root_ents = 512
        self.media = 0xF8
        self.spt = 63
        self.heads = 255
        self.hidden = PART_LBA

        root_secs = (self.root_ents * 32 + SECTOR - 1) // SECTOR
        # Iterate to stable fat size
        fatsecs = 1
        for _ in range(8):
            data_secs = nsectors - self.reserved - self.nfats * fatsecs - root_secs
            if data_secs < 1:
                raise SystemExit("partition too small for FAT16")
            nclust = data_secs // self.sec_per_clust
            fatsecs2 = (nclust * 2 + SECTOR - 1) // SECTOR
            if fatsecs2 == fatsecs:
                break
            fatsecs = max(1, fatsecs2)

        self.fatsecs = fatsecs
        self.root_secs = root_secs
        self.nclust = (nsectors - self.reserved - self.nfats * fatsecs - root_secs) // self.sec_per_clust
        if self.nclust < 4085 or self.nclust > 65524:
            # Keep going anyway for small demo disks; 9load mostly cares about root files.
            pass

        self.data = bytearray(nsectors * SECTOR)
        self.fat = bytearray(self.fatsecs * SECTOR)
        self.root = bytearray(self.root_secs * SECTOR)
        self.fat[0] = self.media
        self.fat[1] = 0xFF
        self.fat[2] = 0xFF
        self.fat[3] = 0xFF
        self.fatlast = 1
        self.root_next = 0
        self.data_off = (
            self.reserved + self.nfats * self.fatsecs + self.root_secs
        ) * SECTOR

    def clustalloc(self, flag: str) -> int:
        if flag != "sof":
            x = 0xFFFF if flag == "eof" else (self.fatlast + 1)
            o = 2 * self.fatlast
            self.fat[o] = x & 0xFF
            self.fat[o + 1] = (x >> 8) & 0xFF
        if flag == "eof":
            return 0
        self.fatlast += 1
        return self.fatlast

    def write_boot_sector(self, pbs: bytes | None) -> None:
        buf = bytearray(SECTOR)
        if pbs:
            buf[:] = pbs[:SECTOR].ljust(SECTOR, b"\0")
        buf[0:3] = b"\xEB\x3C\x90"
        buf[3:11] = b"Plan9.00"
        buf[11:13] = putshort(self.bytes_per_sec)
        buf[13] = self.sec_per_clust
        buf[14:16] = putshort(self.reserved)
        buf[16] = self.nfats
        buf[17:19] = putshort(self.root_ents)
        if self.nsectors < 65536:
            buf[19:21] = putshort(self.nsectors)
        else:
            buf[19:21] = putshort(0)
        buf[21] = self.media
        buf[22:24] = putshort(self.fatsecs)
        buf[24:26] = putshort(self.spt)
        buf[26:28] = putshort(self.heads)
        buf[28:32] = putlong(self.hidden)
        buf[32:36] = putlong(self.nsectors)
        buf[36] = 0x80
        buf[38] = 0x29
        buf[39:43] = putlong(int(time.time()) & 0xFFFFFFFF)
        buf[43:54] = self.label.encode("ascii")
        buf[54:62] = b"FAT16   "
        buf[0x1FE] = 0x55
        buf[0x1FF] = 0xAA
        self.data[0:SECTOR] = buf

    def add_file(self, src: Path, dosname: str | None = None) -> None:
        blob = src.read_bytes()
        name = dosname or src.name
        stem, ext = dos83(name)
        start = 0
        if blob:
            clsz = self.bytes_per_sec * self.sec_per_clust
            nclust = (len(blob) + clsz - 1) // clsz
            padded = blob + b"\0" * (nclust * clsz - len(blob))
            start = self.clustalloc("sof")
            for _ in range(nclust - 1):
                self.clustalloc("mid")
            self.clustalloc("eof")
            off = self.data_off + (start - 2) * clsz
            if off + len(padded) > len(self.data):
                raise SystemExit(f"disk full; cannot add {src}")
            self.data[off : off + len(padded)] = padded

        if self.root_next >= self.root_ents:
            raise SystemExit("root directory full")
        ent = bytearray(32)
        ent[0:8] = stem
        ent[8:11] = ext
        ent[11] = 0x20
        ent[26:28] = putshort(start)
        ent[28:32] = putlong(len(blob))
        o = self.root_next * 32
        self.root[o : o + 32] = ent
        self.root_next += 1
        print(f"  + {name:12}  {len(blob):8} bytes  <- {src}")

    def finalize(self) -> bytes:
        o = self.reserved * SECTOR
        self.data[o : o + len(self.fat)] = self.fat
        o += len(self.fat)
        self.data[o : o + len(self.fat)] = self.fat
        o += len(self.fat)
        self.data[o : o + len(self.root)] = self.root
        return bytes(self.data)


def make_mbr(mbr_code: bytes | None, part_lba: int, part_sectors: int) -> bytes:
    buf = bytearray(SECTOR)
    if mbr_code:
        buf[:] = mbr_code[:SECTOR].ljust(SECTOR, b"\0")
    else:
        # Minimal: hang with message — prefer real Inferno mbr
        buf[0:3] = b"\xEB\xFE\x90"

    # One primary active partition, type 0x06 FAT16
    sc, sh, ss = chs(part_lba)
    ec, eh, es = chs(part_lba + part_sectors - 1)
    ent = bytearray(16)
    ent[0] = 0x80
    ent[1:4] = pack_chs(sc, sh, ss)
    ent[4] = 0x06
    ent[5:8] = pack_chs(ec, eh, es)
    ent[8:12] = putlong(part_lba)
    ent[12:16] = putlong(part_sectors)
    buf[446:462] = ent
    buf[510] = 0x55
    buf[511] = 0xAA
    return bytes(buf)


def parse_file_arg(arg: str) -> tuple[Path, str | None]:
    if "=" in arg:
        path_s, dos = arg.split("=", 1)
        return Path(path_s), dos
    return Path(arg), None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("-m", "--mbr", help="Inferno/386/mbr")
    ap.add_argument("-b", "--boot", help="Inferno/386/pbslba or pbs")
    ap.add_argument("-l", "--label", default="INFERNO")
    ap.add_argument("--size-mb", type=int, default=DEFAULT_MB)
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()

    total_sectors = (args.size_mb * 1024 * 1024) // SECTOR
    part_sectors = total_sectors - PART_LBA
    if part_sectors < 2048:
        raise SystemExit("size too small")

    mbr_code = Path(args.mbr).read_bytes() if args.mbr else None
    pbs = Path(args.boot).read_bytes() if args.boot else None

    print(f"Formatting {args.size_mb}MiB HD image (FAT16 @ LBA {PART_LBA})")
    part = Fat16Partition(part_sectors, label=args.label)
    part.write_boot_sector(pbs)
    for farg in args.files:
        path, dos = parse_file_arg(farg)
        if not path.is_file():
            raise SystemExit(f"missing file: {path}")
        part.add_file(path, dos)

    img = bytearray(total_sectors * SECTOR)
    img[0:SECTOR] = make_mbr(mbr_code, PART_LBA, part_sectors)
    part_blob = part.finalize()
    img[PART_LBA * SECTOR : PART_LBA * SECTOR + len(part_blob)] = part_blob

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(img)
    print(f"Wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
