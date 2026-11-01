"""Load an add-on exactly as the client would: in .toc order."""

from __future__ import annotations

from pathlib import Path

from .wow_mock import WowRuntime


def parse_toc(toc_path: Path) -> list[str]:
    """Return the file list from a .toc, preserving order.

    Lines starting with '#' are comments. Backslashes are normalised so the
    same add-on works on Windows and Linux CI.
    """
    files: list[str] = []
    for line in toc_path.read_text(encoding="utf-8-sig").splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        files.append(entry.replace("\\", "/"))
    return files


def load_addon(runtime: WowRuntime, addon_dir: Path) -> list[str]:
    """Load every file listed in <addon_dir>/<name>.toc.

    Each file is wrapped in a vararg function so both `...` values behave like
    the real client: addon name first, shared namespace second.
    """
    addon_dir = Path(addon_dir).resolve()
    toc_path = addon_dir / f"{addon_dir.name}.toc"
    if not toc_path.is_file():
        raise FileNotFoundError(f"missing toc: {toc_path}")

    files = parse_toc(toc_path)
    namespace = runtime.L.eval("{}")

    for relative in files:
        source = (addon_dir / relative).resolve()
        if addon_dir not in source.parents:
            raise ValueError(f"toc entry escapes add-on directory: {relative}")
        if not source.is_file():
            raise FileNotFoundError(f"toc entry does not exist: {source}")

        code = source.read_text(encoding="utf-8-sig")
        chunk = runtime.L.eval("function(...)\n" + code + "\nend")
        chunk(addon_dir.name, namespace)

    return files
