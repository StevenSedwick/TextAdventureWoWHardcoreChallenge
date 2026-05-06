"""Standalone WoW screenshot janitor.

Aggressively deletes WoWScrnShot_*.jpg / *.jpeg files from the WoW
Screenshots directory on a fast polling loop. Runs independently of the
look accessibility ML pipeline so the folder stays clean during streaming
even when no capture service is active.

Usage:
    python screenshot_janitor.py
    python screenshot_janitor.py --interval 0.25 --dir "C:/path/to/Screenshots"
    python screenshot_janitor.py --once
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path
from typing import Optional

PATTERNS = ("WoWScrnShot_*.jpg", "WoWScrnShot_*.jpeg", "WoWScrnShot_*.png", "WoWScrnShot_*.tga")


def default_screenshots_dir() -> Optional[Path]:
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "Screenshots"
        if candidate.is_dir():
            return candidate
    return None


def sweep(directory: Path) -> int:
    deleted = 0
    for pattern in PATTERNS:
        for path in directory.glob(pattern):
            try:
                path.unlink()
                deleted += 1
            except FileNotFoundError:
                pass
            except OSError as exc:
                print(f"[JANITOR] Failed to delete {path}: {exc}", file=sys.stderr)
    return deleted


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Wipe WoW screenshot JPGs.")
    parser.add_argument("--dir", default="", help="Screenshots directory (default: auto-detect)")
    parser.add_argument("--interval", type=float, default=0.5, help="Polling interval in seconds")
    parser.add_argument("--once", action="store_true", help="Sweep once and exit")
    parser.add_argument("--quiet", action="store_true", help="Only log when files are deleted")
    args = parser.parse_args(argv)

    directory = Path(args.dir) if args.dir else default_screenshots_dir()
    if directory is None or not directory.is_dir():
        print(f"[JANITOR] Screenshots directory not found: {directory}", file=sys.stderr)
        return 1

    print(f"[JANITOR] Watching {directory}")
    if args.once:
        deleted = sweep(directory)
        print(f"[JANITOR] Deleted {deleted} file(s)")
        return 0

    print(f"[JANITOR] Interval: {args.interval}s. Ctrl+C to stop.")
    try:
        while True:
            deleted = sweep(directory)
            if deleted or not args.quiet:
                if deleted:
                    print(f"[JANITOR] Deleted {deleted} file(s)")
            time.sleep(max(0.05, args.interval))
    except KeyboardInterrupt:
        print("[JANITOR] Stopped")
        return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
