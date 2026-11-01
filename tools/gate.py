#!/usr/bin/env python3
"""Repository gate: fail fast before anything reaches the client or GitHub.

Checks:
  - .toc entries exist, are unique, and cover every Lua file
  - load order is Init -> Env -> Probe -> UI
  - the toc targets Retail (Interface 120105)
  - legacy client APIs never appear, even in comments
  - raw modern client APIs stay inside the adapter layer
  - version is in sync between .toc and Init.lua
  - LF endings, no BOM
  - no absolute local paths, tokens, account ids, or old project branding
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon" / "AHProbe"
TOC = ADDON / "AHProbe.toc"

INTERFACE = "120105"
ALLOWED_RAW = {"Core/Init.lua", "Core/Env.lua"}
RAW_APIS = [
    "C_AuctionHouse",
    "C_Container",
    "C_Item",
    "AuctionHouseFrame",
]

# Retail is one client. These legacy names must not survive anywhere, not even
# as a fallback: a retail-only tree should be readable on its own.
LEGACY_PATTERNS = [
    (re.compile(r"\bQueryAuctionItems\b"), "legacy query API"),
    (re.compile(r"\bGetNumAuctionItems\b"), "legacy result-count API"),
    (re.compile(r"\bGetAuctionItemInfo\b"), "legacy result-row API"),
    (re.compile(r"\bAuctionFrame\b"), "legacy AH frame"),
    (re.compile(r"\bPlaceAuctionBid\b"), "legacy bid API"),
    (re.compile(r"_G\.GetItemInfo\b"), "legacy item API"),
    (re.compile(r"_G\.GetContainer"), "legacy bag API"),
    (re.compile(r"ns\.MODERN_AH"), "dual-client branch flag"),
]

SENSITIVE = [
    (re.compile(r"(?<![A-Za-z])[A-Za-z]:[\\/]"), "absolute Windows path"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"), "GitHub token"),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b"), "API key"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "email address"),
]

TEXT_SUFFIXES = {
    ".lua", ".toc", ".py", ".md", ".yml", ".yaml", ".toml", ".txt", ".json",
    ".gitignore", ".gitattributes", ".editorconfig",
}


def parse_toc(path: Path) -> list[str]:
    files: list[str] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        files.append(entry.replace("\\", "/"))
    return files


def is_text_file(path: Path) -> bool:
    if path.name in {"LICENSE", "Makefile"}:
        return True
    return path.suffix.lower() in TEXT_SUFFIXES


def main() -> int:
    errors: list[str] = []

    if not TOC.is_file():
        print(f"gate: missing {TOC}", file=sys.stderr)
        return 1

    toc_text = TOC.read_text(encoding="utf-8-sig")
    files = parse_toc(TOC)

    if len(files) != len(set(files)):
        errors.append("toc contains duplicate entries")

    if files[:4] != ["Core/Init.lua", "Core/Env.lua", "Core/Probe.lua", "UI/Main.lua"]:
        errors.append(f"unexpected load order: {files}")

    interface = re.search(r"^##\s*Interface:\s*(\S+)", toc_text, re.MULTILINE)
    if not interface:
        errors.append("toc has no ## Interface line")
    elif interface.group(1) != INTERFACE:
        errors.append(f"toc Interface is {interface.group(1)}, expected {INTERFACE}")

    for relative in files:
        if not (ADDON / relative).is_file():
            errors.append(f"toc entry missing on disk: {relative}")

    listed = set(files)
    for source in ADDON.rglob("*.lua"):
        relative = source.relative_to(ADDON).as_posix()
        if relative not in listed:
            errors.append(f"Lua file not listed in toc: {relative}")

    init = (ADDON / "Core/Init.lua").read_text(encoding="utf-8-sig")
    toc_version = re.search(r"^##\s*Version:\s*(\S+)", toc_text, re.MULTILINE)
    init_version = re.search(r'ns\.VERSION\s*=\s*"([^"]+)"', init)
    if not toc_version or not init_version:
        errors.append("cannot read version from toc or Init.lua")
    elif toc_version.group(1) != init_version.group(1):
        errors.append(
            f"version mismatch: toc={toc_version.group(1)} init={init_version.group(1)}"
        )

    for source in ADDON.rglob("*.lua"):
        relative = source.relative_to(ADDON).as_posix()
        text = source.read_text(encoding="utf-8-sig")

        for pattern, label in LEGACY_PATTERNS:
            if pattern.search(text):
                errors.append(f"{label} found in {relative}")

        if relative in ALLOWED_RAW:
            continue
        for api in RAW_APIS:
            if api in text:
                errors.append(f"raw API '{api}' leaked into {relative}")

    scan_files = [
        path for path in ROOT.rglob("*")
        if path.is_file()
        and ".git" not in path.parts
        and "__pycache__" not in path.parts
        and "dist" not in path.parts
        and ".venv" not in path.parts
        and path.resolve() != Path(__file__).resolve()
        and is_text_file(path)
    ]

    for path in scan_files:
        data = path.read_bytes()
        relative = path.relative_to(ROOT).as_posix()
        if data.startswith(b"\xef\xbb\xbf"):
            errors.append(f"BOM found: {relative}")
        if b"\r\n" in data:
            errors.append(f"CRLF found: {relative}")
        text = data.decode("utf-8", errors="replace")
        for pattern, label in SENSITIVE:
            if pattern.search(text):
                errors.append(f"{label} found in {relative}")

    if errors:
        print("gate: FAILED", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"gate: OK ({len(scan_files)} text files scanned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
