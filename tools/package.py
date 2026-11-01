#!/usr/bin/env python3
"""Build an installable Retail add-on folder from the source tree."""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon" / "AHProbe"
TOC = ADDON / "AHProbe.toc"
INTERFACE = "120105"


def parse_toc(path: Path) -> list[str]:
    files: list[str] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        files.append(entry.replace("\\", "/"))
    return files


def package(out_dir: Path) -> Path:
    destination = out_dir / "AHProbe" / "AHProbe"

    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)

    files = parse_toc(TOC)
    for relative in files:
        source = ADDON / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)

    lines = TOC.read_text(encoding="utf-8-sig").splitlines()
    output: list[str] = []
    for line in lines:
        if line.startswith("## Interface:"):
            line = f"## Interface: {INTERFACE}"
        output.append(line)

    (destination / "AHProbe.toc").write_text(
        "\n".join(output) + "\n", encoding="utf-8", newline="\n"
    )

    print(f"packaged retail: {destination} ({len(files)} Lua files)")
    return destination


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "dist")
    args = parser.parse_args()

    package(args.out.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
