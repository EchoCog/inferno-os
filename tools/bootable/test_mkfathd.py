#!/usr/bin/env python3
"""Smoke test for mkfathd.py — no Inferno toolchain required."""

from __future__ import annotations

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MKHD = ROOT / "mkfathd.py"


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        kernel = td_path / "ieasy"
        ini = td_path / "plan9.ini"
        load = td_path / "9load"
        kernel.write_bytes(b"K" * 8192)
        ini.write_text("bootfile=hd0!dos!ieasy\nloco=8080\n")
        load.write_bytes(b"L" * 4096)
        pbs = td_path / "pbs"
        pbs.write_bytes(b"\xEB\x3C\x90" + b"\0" * 507 + b"\x55\xAA")
        mbr = td_path / "mbr"
        mbr.write_bytes(b"\xEB\xFE\x90" + b"\0" * 507 + b"\x55\xAA")

        out = td_path / "hd.img"
        subprocess.check_call(
            [
                sys.executable,
                str(MKHD),
                "-o",
                str(out),
                "-m",
                str(mbr),
                "-b",
                str(pbs),
                "--size-mb",
                "8",
                f"{load}=9LOAD",
                f"{ini}=PLAN9.INI",
                f"{kernel}=IEASY",
            ]
        )

        data = out.read_bytes()
        assert len(data) == 8 * 1024 * 1024, len(data)
        assert data[510:512] == b"\x55\xAA"
        # active partition @ 446
        assert data[446] == 0x80
        assert data[450] == 0x06  # FAT16
        part_lba = struct.unpack_from("<I", data, 446 + 8)[0]
        assert part_lba == 63, part_lba
        part = data[part_lba * 512 :]
        assert part[0:3] == b"\xEB\x3C\x90"
        assert part[54:62] == b"FAT16   "
        print("ok: mkfathd smoke test passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
