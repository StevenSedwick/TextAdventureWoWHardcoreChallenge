#!/usr/bin/env python3
"""
Train a lightweight world-conditioned scene model for WoW accessibility descriptions.

Input: CSV with screenshot path + world telemetry + multi-label tags.
Output: serialized sklearn artifacts for local inference.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from PIL import Image
from sklearn.metrics import f1_score
from sklearn.model_selection import train_test_split
from sklearn.multioutput import MultiOutputClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


REQUIRED_COLUMNS = {
    "sample_id",
    "image_path",
    "zone",
    "map_id",
    "pos_x",
    "pos_y",
    "facing_radians",
    "camera_pitch",
    "camera_zoom",
    "label_tags",
}


def image_features(image_path: Path, bins: int) -> np.ndarray:
    img = Image.open(image_path).convert("RGB").resize((160, 90))
    arr = np.asarray(img, dtype=np.float32) / 255.0

    # RGB histogram features
    hist_feats = []
    for channel in range(3):
        h, _ = np.histogram(arr[:, :, channel], bins=bins, range=(0.0, 1.0), density=True)
        hist_feats.extend(h.tolist())

    # Edge-density style feature via luminance gradients
    lum = 0.2126 * arr[:, :, 0] + 0.7152 * arr[:, :, 1] + 0.0722 * arr[:, :, 2]
    gx = np.abs(np.diff(lum, axis=1)).mean()
    gy = np.abs(np.diff(lum, axis=0)).mean()

    return np.array(hist_feats + [float(gx), float(gy)], dtype=np.float32)


def build_feature_matrix(df: pd.DataFrame, csv_dir: Path, bins: int):
    numeric = df[["pos_x", "pos_y", "camera_pitch", "camera_zoom"]].astype(np.float32).copy()
    numeric["facing_sin"] = np.sin(df["facing_radians"].astype(np.float32))
    numeric["facing_cos"] = np.cos(df["facing_radians"].astype(np.float32))

    categorical = pd.get_dummies(df[["zone", "map_id"]].astype(str), prefix=["zone", "map"])

    img_rows = []
    for rel_path in df["image_path"].astype(str).tolist():
        image_path = (csv_dir / rel_path).resolve()
        img_rows.append(image_features(image_path, bins=bins))
    img_arr = np.vstack(img_rows)
    img_cols = [f"img_feat_{i}" for i in range(img_arr.shape[1])]
    img_df = pd.DataFrame(img_arr, columns=img_cols)

    X_df = pd.concat([numeric.reset_index(drop=True), categorical.reset_index(drop=True), img_df.reset_index(drop=True)], axis=1)
    return X_df


def build_label_matrix(df: pd.DataFrame):
    vocab = set()
    rows = []
    for raw in df["label_tags"].astype(str).tolist():
        tags = [t.strip() for t in raw.split(";") if t.strip()]
        rows.append(tags)
        vocab.update(tags)

    label_list = sorted(vocab)
    index = {label: i for i, label in enumerate(label_list)}

    y = np.zeros((len(rows), len(label_list)), dtype=np.int32)
    for r, tags in enumerate(rows):
        for t in tags:
            y[r, index[t]] = 1

    return y, label_list


def parse_args():
    parser = argparse.ArgumentParser(description="Train world-conditioned WoW scene model")
    parser.add_argument("--dataset", required=True, help="Path to CSV dataset")
    parser.add_argument("--out-dir", default="tools/look_accessibility/model", help="Output model directory")
    parser.add_argument("--bins", type=int, default=16, help="Histogram bins per RGB channel")
    parser.add_argument("--hidden1", type=int, default=128, help="MLP hidden layer 1 size")
    parser.add_argument("--hidden2", type=int, default=64, help="MLP hidden layer 2 size")
    parser.add_argument("--max-iter", type=int, default=300, help="MLP max iterations")
    parser.add_argument("--test-size", type=float, default=0.2, help="Validation split fraction")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dataset_path = Path(args.dataset).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(dataset_path)
    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise ValueError(f"Dataset missing required columns: {sorted(missing)}")

    csv_dir = dataset_path.parent
    X_df = build_feature_matrix(df, csv_dir=csv_dir, bins=args.bins)
    y, labels = build_label_matrix(df)

    X = X_df.to_numpy(dtype=np.float32)
    X_train, X_val, y_train, y_val = train_test_split(
        X,
        y,
        test_size=args.test_size,
        random_state=args.seed,
    )

    base = MLPClassifier(
        hidden_layer_sizes=(args.hidden1, args.hidden2),
        activation="relu",
        solver="adam",
        alpha=1e-4,
        batch_size=64,
        learning_rate_init=1e-3,
        max_iter=args.max_iter,
        random_state=args.seed,
    )

    model = Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            ("clf", MultiOutputClassifier(base)),
        ]
    )

    model.fit(X_train, y_train)

    y_pred = model.predict(X_val)
    micro_f1 = float(f1_score(y_val, y_pred, average="micro", zero_division=0))
    macro_f1 = float(f1_score(y_val, y_pred, average="macro", zero_division=0))

    joblib.dump(model, out_dir / "scene_model.joblib")
    (out_dir / "labels.txt").write_text("\n".join(labels) + "\n", encoding="utf-8")
    (out_dir / "feature_columns.json").write_text(json.dumps(X_df.columns.tolist(), indent=2), encoding="utf-8")

    metrics = {
        "samples": int(len(df)),
        "features": int(X.shape[1]),
        "labels": int(len(labels)),
        "micro_f1": micro_f1,
        "macro_f1": macro_f1,
    }
    (out_dir / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    print("Training complete")
    print(json.dumps(metrics, indent=2))
    print(f"Artifacts written to: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
