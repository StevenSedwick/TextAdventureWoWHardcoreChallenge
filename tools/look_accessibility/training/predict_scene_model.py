#!/usr/bin/env python3
"""
Run local inference with the trained world-conditioned scene model.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from PIL import Image


def image_features(image_path: Path, bins: int) -> np.ndarray:
    img = Image.open(image_path).convert("RGB").resize((160, 90))
    arr = np.asarray(img, dtype=np.float32) / 255.0

    hist_feats = []
    for channel in range(3):
        h, _ = np.histogram(arr[:, :, channel], bins=bins, range=(0.0, 1.0), density=True)
        hist_feats.extend(h.tolist())

    lum = 0.2126 * arr[:, :, 0] + 0.7152 * arr[:, :, 1] + 0.0722 * arr[:, :, 2]
    gx = np.abs(np.diff(lum, axis=1)).mean()
    gy = np.abs(np.diff(lum, axis=0)).mean()

    return np.array(hist_feats + [float(gx), float(gy)], dtype=np.float32)


def parse_args():
    parser = argparse.ArgumentParser(description="Predict scene tags from image + world telemetry")
    parser.add_argument("--model-dir", default="tools/look_accessibility/model", help="Model artifact directory")
    parser.add_argument("--image", required=True, help="Input screenshot path")
    parser.add_argument("--zone", required=True)
    parser.add_argument("--map-id", required=True)
    parser.add_argument("--x", type=float, required=True)
    parser.add_argument("--y", type=float, required=True)
    parser.add_argument("--facing", type=float, required=True)
    parser.add_argument("--pitch", type=float, default=0.0)
    parser.add_argument("--zoom", type=float, default=2.6)
    parser.add_argument("--bins", type=int, default=16)
    parser.add_argument("--threshold", type=float, default=0.5)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    model_dir = Path(args.model_dir).resolve()
    model = joblib.load(model_dir / "scene_model.joblib")
    labels = [line.strip() for line in (model_dir / "labels.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    feature_columns = json.loads((model_dir / "feature_columns.json").read_text(encoding="utf-8"))

    row = {
        "pos_x": args.x,
        "pos_y": args.y,
        "camera_pitch": args.pitch,
        "camera_zoom": args.zoom,
        "facing_sin": float(np.sin(args.facing)),
        "facing_cos": float(np.cos(args.facing)),
        f"zone_{args.zone}": 1,
        f"map_{args.map_id}": 1,
    }

    img_feat = image_features(Path(args.image).resolve(), bins=args.bins)
    for i, v in enumerate(img_feat.tolist()):
        row[f"img_feat_{i}"] = v

    x_df = pd.DataFrame([row])
    for c in feature_columns:
        if c not in x_df.columns:
            x_df[c] = 0
    x_df = x_df[feature_columns]

    x = x_df.to_numpy(dtype=np.float32)
    y_pred = model.predict(x)[0]

    active = [labels[i] for i, flag in enumerate(y_pred.tolist()) if flag == 1]

    description_bits = []
    if any(t.startswith("terrain_") for t in active):
        terrain = [t.replace("terrain_", "") for t in active if t.startswith("terrain_")]
        if terrain:
            description_bits.append(f"Terrain appears {terrain[0]}")
    if any(t.startswith("road_") for t in active):
        roads = [t.replace("road_", "") for t in active if t.startswith("road_")]
        if roads:
            description_bits.append(f"road/path: {roads[0]}")
    if any(t.startswith("enemy_") for t in active):
        enemies = [t.replace("enemy_", "") for t in active if t.startswith("enemy_")]
        if enemies:
            description_bits.append(f"possible enemy: {enemies[0]}")
    if any(t.startswith("obstacle_") for t in active):
        obstacles = [t.replace("obstacle_", "") for t in active if t.startswith("obstacle_")]
        if obstacles:
            description_bits.append(f"obstacle: {obstacles[0]}")

    if not description_bits:
        description = "Scene uncertain from current model confidence."
    else:
        description = ". ".join(description_bits)
        if not description.endswith("."):
            description += "."

    print("Predicted tags:", ", ".join(active) if active else "(none)")
    print("Description:", description)
    print("Paste into game:")
    print(f"/look set {description}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
