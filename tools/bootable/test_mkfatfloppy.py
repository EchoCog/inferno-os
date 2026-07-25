#!/usr/bin/env python3
"""Smoke test for mkfatfloppy.py — no Inferno toolchain required."""

from __future__ import annotations

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MKFAT = ROOT / "mkfatfloppy.py"


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        a = td_path / "hello.txt"
        b = td_path / "kernel.bin"
        a.write_text("hello inferno\n")
        b.write_bytes(b"\x00" * 4096 + b"IEASY")
        # Minimal fake PBS: 512 bytes ending 55 AA
        pbs = td_path / "pbs"
        pbs.write_bytes(b"\xEB\x3C\x90" + b"\0" * 507 + b"\x55\xAA")

        out = td_path / "test.img"
        subprocess.check_call(
            [
                sys.executable,
                str(MKFAT),
                "-o",
                str(out),
                "-b",
                str(pbs),
                str(a) + "=HELLO.TXT",
                str(b) + "=IEASY",
            ]
        )

        data = out.read_bytes()
        assert len(data) == 1474560, len(data)
        assert data[0:3] == b"\xEB\x3C\x90"
        assert data[0x1FE:0x200] == b"\x55\xAA"
        sectsize = struct.unpack_from("<H", data, 11)[0]
        assert sectsize == 512
        assert data[54:62] == b"FAT12   "
        # Root dir should mention HELLO and IEASY
        # Reserved(1) + 2*FATs; fatsecs from image BPB
        fatsecs = struct.unpack_from("<H", data, 22)[0]
        root_off = 512 + 2 * fatsecs * 512
        root = data[root_off : root_off + 14 * 512]
        assert b"HELLO   TXT" in root
        assert b"IEASY      " in root
        print("ok: mkfatfloppy smoke test passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
