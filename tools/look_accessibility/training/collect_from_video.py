#!/usr/bin/env python3
"""
Extract labeled frames from a recorded WoW video and append them to dataset CSV.

This is useful when you want to record once, then create many labeled samples
without manually capturing each frame in real-time.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
from pathlib import Path
from typing import Dict

import cv2


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


def parse_telemetry(line: str) -> Dict[str, str]:
    payload = line.strip()
    if payload.startswith("LOOK_TELEMETRY"):
        payload = payload[len("LOOK_TELEMETRY") :].strip()

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


def append_rows(csv_path: Path, rows):
    with csv_path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=REQUIRED_FIELDS)
        for row in rows:
            writer.writerow(row)


def parse_args():
    parser = argparse.ArgumentParser(description="Collect labeled /look samples from video")
    parser.add_argument("--video", required=True, help="Path to recorded video file")
    parser.add_argument(
        "--dataset-csv",
        default="tools/look_accessibility/training/collected_dataset.csv",
        help="Output CSV path",
    )
    parser.add_argument(
        "--frames-dir",
        default="tools/look_accessibility/training/samples_video",
        help="Folder to write extracted frames",
    )
    parser.add_argument("--every-n-frames", type=int, default=15, help="Keep one frame every N frames")
    parser.add_argument("--max-frames", type=int, default=0, help="0 = no limit")

    parser.add_argument("--source-env", default="live_classic_era")
    parser.add_argument("--zone", default="")
    parser.add_argument("--map-id", default="")
    parser.add_argument("--x", default="")
    parser.add_argument("--y", default="")
    parser.add_argument("--facing", default="")
    parser.add_argument("--pitch", default="")
    parser.add_argument("--zoom", default="")

    parser.add_argument("--labels", default="", help="Semicolon-separated labels to apply to every frame")
    parser.add_argument("--description", default="", help="Optional description to apply to every frame")
    parser.add_argument(
        "--telemetry-line",
        default="",
        help="Optional LOOK_TELEMETRY line to auto-fill zone/map/pos/facing/pitch/zoom/labels",
    )
    parser.add_argument("--image-ext", choices=["png", "jpg"], default="png")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    video_path = Path(args.video).resolve()
    if not video_path.exists():
        raise FileNotFoundError(f"Video not found: {video_path}")

    csv_path = Path(args.dataset_csv).resolve()
    frames_dir = Path(args.frames_dir).resolve()
    ensure_csv(csv_path)
    frames_dir.mkdir(parents=True, exist_ok=True)

    telemetry = parse_telemetry(args.telemetry_line) if args.telemetry_line.strip() else {}

    labels = args.labels.strip() or telemetry.get("labels", "")
    if not labels:
        raise ValueError("No labels provided. Use --labels or include labels=... in --telemetry-line")

    zone = args.zone or telemetry.get("zone", "")
    map_id = args.map_id or telemetry.get("map", "")
    pos_x = args.x or telemetry.get("x", "")
    pos_y = args.y or telemetry.get("y", "")
    facing = args.facing or telemetry.get("facing", "")
    pitch = args.pitch or telemetry.get("pitch", "")
    zoom = args.zoom or telemetry.get("zoom", "")

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError(f"Unable to open video: {video_path}")

    every_n = max(1, int(args.every_n_frames))
    max_frames = max(0, int(args.max_frames))

    extracted_rows = []
    frame_index = 0
    kept_count = 0
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")

    while True:
        ok, frame = cap.read()
        if not ok:
            break

        if frame_index % every_n != 0:
            frame_index += 1
            continue

        sample_id = f"video_{stamp}_{frame_index:07d}"
        image_name = f"{sample_id}.{args.image_ext}"
        image_path = frames_dir / image_name

        if args.image_ext == "jpg":
            cv2.imwrite(str(image_path), frame, [int(cv2.IMWRITE_JPEG_QUALITY), 95])
        else:
            cv2.imwrite(str(image_path), frame)

        rel_image = image_path.relative_to(csv_path.parent).as_posix()
        extracted_rows.append(
            {
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
                "label_tags": labels,
                "description": args.description,
            }
        )

        kept_count += 1
        if max_frames and kept_count >= max_frames:
            break

        frame_index += 1

    cap.release()

    append_rows(csv_path, extracted_rows)
    print(f"Video: {video_path}")
    print(f"Rows appended: {len(extracted_rows)}")
    print(f"Dataset: {csv_path}")
    print(f"Frames dir: {frames_dir}")
    print(f"Labels: {labels}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
