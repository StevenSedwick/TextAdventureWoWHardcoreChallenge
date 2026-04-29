#!/usr/bin/env python3
"""
Dataset collector for world-conditioned /look training.

Workflow per sample:
1) Capture WoW frame.
2) In-game run: /ta look telemetry
3) Paste telemetry line into collector prompt.
4) Enter label tags + optional description.
5) Collector appends a CSV row.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import importlib.util
import time
from pathlib import Path
from typing import Dict

try:
    import keyboard
except Exception:
    keyboard = None

REQUIRED_FIELDS = [
    "sample_id",
    "image_path",
    "source_env",
    "zone",
    "map_id",
    "pos_x",
    "pos_y",
    "facing_radians",
    "camera_pitch",
    "camera_zoom",
    "label_tags",
    "description",
]


def load_capture_module(workspace_root: Path):
    module_path = workspace_root / "tools" / "look_accessibility" / "look_capture_service.py"
    spec = importlib.util.spec_from_file_location("look_capture_service", str(module_path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load capture module: {module_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def parse_telemetry(line: str) -> Dict[str, str]:
    payload = line.strip()
    if payload.startswith("LOOK_TELEMETRY"):
        payload = payload[len("LOOK_TELEMETRY"):].strip()

    result: Dict[str, str] = {}
    for token in payload.split():
        if "=" not in token:
            continue
        k, v = token.split("=", 1)
        result[k.strip().lower()] = v.strip()
    return result


def ensure_csv(csv_path: Path):
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    if csv_path.exists():
        return
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=REQUIRED_FIELDS)
        writer.writeheader()


def append_row(csv_path: Path, row: Dict[str, str]):
    with csv_path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=REQUIRED_FIELDS)
        writer.writerow(row)


def collect_once(args, capture_mod):
    samples_dir = Path(args.samples_dir).resolve()
    csv_path = Path(args.dataset_csv).resolve()

    ensure_csv(csv_path)
    samples_dir.mkdir(parents=True, exist_ok=True)

    ts = dt.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    sample_id = f"sample_{ts}"
    image_file = f"{sample_id}.png"
    image_path = samples_dir / image_file

    capture = capture_mod.capture_wow_frame(output_path=image_path, window_title=args.window_title)

    print("Captured:", image_path)
    print("Capture mode:", capture.mode)
    print("In WoW run: /ta look telemetry")
    telemetry_line = input("Paste LOOK_TELEMETRY line: ").strip()
    t = parse_telemetry(telemetry_line)

    auto_tags = t.get("labels", "")
    if auto_tags:
        print("Auto labels from telemetry:", auto_tags)
    tags = input("Label tags (Enter to keep auto labels): ").strip()
    if not tags:
        tags = auto_tags

    description = input("Description (optional): ").strip()

    zone = t.get("zone", "")
    map_id = t.get("map", "")
    pos_x = t.get("x", "")
    pos_y = t.get("y", "")
    facing = t.get("facing", "")
    pitch = t.get("pitch", "")
    zoom = t.get("zoom", "")

    rel_image = image_path.relative_to(csv_path.parent).as_posix()

    row = {
        "sample_id": sample_id,
        "image_path": rel_image,
        "source_env": args.source_env,
        "zone": zone,
        "map_id": map_id,
        "pos_x": pos_x,
        "pos_y": pos_y,
        "facing_radians": facing,
        "camera_pitch": pitch,
        "camera_zoom": zoom,
        "label_tags": tags,
        "description": description,
    }

    append_row(csv_path, row)
    print("Saved row to:", csv_path)
    print("Sample ID:", sample_id)


def run_hotkey_loop(args, capture_mod):
    if keyboard is None:
        raise RuntimeError("keyboard package is required for --watch mode. Install with: pip install keyboard")

    print("Hotkey collection mode started")
    print("Capture hotkey:", args.hotkey)
    print("Press ESC to quit")

    while True:
        if keyboard.is_pressed("esc"):
            print("Exiting hotkey collection loop")
            break

        if keyboard.is_pressed(args.hotkey):
            print("\n=== Hotkey capture triggered ===")
            collect_once(args, capture_mod)
            # Debounce to avoid duplicate captures from one key press.
            time.sleep(0.8)

        time.sleep(0.05)


def parse_args():
    parser = argparse.ArgumentParser(description="Collect /look training samples")
    parser.add_argument("--workspace-root", default=".")
    parser.add_argument("--window-title", default="World of Warcraft")
    parser.add_argument(
        "--source-env",
        default="live_classic_era",
        help="Dataset source environment tag (default: live_classic_era)",
    )
    parser.add_argument(
        "--dataset-csv",
        default="tools/look_accessibility/training/collected_dataset.csv",
    )
    parser.add_argument(
        "--samples-dir",
        default="tools/look_accessibility/training/samples",
    )
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--watch", action="store_true", help="Run continuous hotkey capture loop")
    parser.add_argument("--hotkey", default="ctrl+shift+k", help="Hotkey used in --watch mode")
    return parser.parse_args()


def main():
    args = parse_args()
    workspace_root = Path(args.workspace_root).resolve()
    capture_mod = load_capture_module(workspace_root)

    if args.watch:
        run_hotkey_loop(args, capture_mod)
    else:
        for i in range(args.count):
            print(f"\n=== Collecting sample {i + 1}/{args.count} ===")
            collect_once(args, capture_mod)

    print("Done collecting samples.")


if __name__ == "__main__":
    main()
