#!/usr/bin/env python3
"""
Accessibility prototype: capture the WoW window and produce a short scene description.

Safety rules:
- Read-only visual analysis.
- No movement, targeting, spell casting, or gameplay automation.
- Output is plain text for player decision support.
"""

from __future__ import annotations

import argparse
import base64
import ctypes
import datetime as dt
import json
import random
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

try:
    import numpy as np
except Exception:
    np = None

try:
    import pandas as pd
except Exception:
    pd = None

try:
    import joblib
except Exception:
    joblib = None

try:
    import onnxruntime as ort
except Exception:
    ort = None

try:
    import requests
except Exception:
    requests = None

try:
    import mss
except Exception:
    mss = None

try:
    from PIL import Image, ImageGrab
except Exception:
    Image = None
    ImageGrab = None

try:
    import win32con
    import win32gui
    import win32ui
except Exception:
    win32con = None
    win32gui = None
    win32ui = None

try:
    import keyboard
except Exception:
    keyboard = None


@dataclass
class CaptureResult:
    image_path: Path
    width: int
    height: int
    mode: str


def find_wow_window(title_hint: str = "World of Warcraft") -> Optional[int]:
    if not win32gui:
        return None

    matches = []

    def enum_handler(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd):
            return
        title = win32gui.GetWindowText(hwnd) or ""
        if title_hint.lower() in title.lower():
            matches.append(hwnd)

    win32gui.EnumWindows(enum_handler, None)
    return matches[0] if matches else None


def capture_with_printwindow(hwnd: int, output_path: Path) -> Optional[CaptureResult]:
    if not (win32gui and win32ui and win32con and Image):
        return None

    left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    width = right - left
    height = bottom - top

    hwnd_dc = win32gui.GetWindowDC(hwnd)
    mfc_dc = win32ui.CreateDCFromHandle(hwnd_dc)
    save_dc = mfc_dc.CreateCompatibleDC()

    bitmap = win32ui.CreateBitmap()
    bitmap.CreateCompatibleBitmap(mfc_dc, width, height)
    save_dc.SelectObject(bitmap)

    PW_RENDERFULLCONTENT = 0x00000002
    try:
        if hasattr(win32gui, "PrintWindow"):
            result = win32gui.PrintWindow(hwnd, save_dc.GetSafeHdc(), PW_RENDERFULLCONTENT)
        else:
            result = ctypes.windll.user32.PrintWindow(int(hwnd), int(save_dc.GetSafeHdc()), PW_RENDERFULLCONTENT)
    except Exception:
        result = 0

    bmp_info = bitmap.GetInfo()
    bmp_str = bitmap.GetBitmapBits(True)
    image = Image.frombuffer(
        "RGB",
        (bmp_info["bmWidth"], bmp_info["bmHeight"]),
        bmp_str,
        "raw",
        "BGRX",
        0,
        1,
    )

    win32gui.DeleteObject(bitmap.GetHandle())
    save_dc.DeleteDC()
    mfc_dc.DeleteDC()
    win32gui.ReleaseDC(hwnd, hwnd_dc)

    if result != 1:
        return None

    image.save(output_path)
    return CaptureResult(output_path, width, height, "window-print")


def capture_with_mss(hwnd: int, output_path: Path) -> Optional[CaptureResult]:
    if not (mss and win32gui):
        return None

    left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    width = right - left
    height = bottom - top

    with mss.mss() as sct:
        monitor = {
            "left": left,
            "top": top,
            "width": width,
            "height": height,
        }
        shot = sct.grab(monitor)
        if Image is None:
            return None
        img = Image.frombytes("RGB", shot.size, shot.rgb)
        img.save(output_path)

    return CaptureResult(output_path, width, height, "window-rect")


def capture_with_imagegrab(output_path: Path) -> Optional[CaptureResult]:
    if not ImageGrab:
        return None

    img = ImageGrab.grab()
    img.save(output_path)
    return CaptureResult(output_path, img.width, img.height, "fullscreen")


def capture_wow_frame(output_path: Path, window_title: str) -> CaptureResult:
    hwnd = find_wow_window(window_title)
    if hwnd:
        result = capture_with_printwindow(hwnd, output_path)
        if result:
            return result
        result = capture_with_mss(hwnd, output_path)
        if result:
            return result

    fallback = capture_with_imagegrab(output_path)
    if fallback:
        return fallback

    raise RuntimeError(
        "Failed to capture frame. Install dependencies and run WoW in windowed/borderless mode."
    )


def describe_placeholder(image_path: Path) -> str:
    random.seed(int(time.time()))
    samples = [
        "You are facing a road. A steep drop appears ahead-left. One hostile is visible near center-right. Trees thicken on the right side.",
        "You are near uneven terrain. A path bends forward-right. A building-like silhouette appears at medium distance.",
        "Open ground extends ahead. Obstacles cluster left of center, with possible interactable objects near the roadside.",
    ]
    return random.choice(samples)


def describe_with_ollama(image_path: Path, model: str) -> str:
    if requests is None:
        raise RuntimeError("requests is not installed. pip install requests")

    with image_path.open("rb") as fh:
        image_b64 = base64.b64encode(fh.read()).decode("utf-8")

    prompt = (
        "Describe this WoW Classic scene for accessibility in 1-2 concise sentences. "
        "Mention terrain shape, cliffs/drops, roads/paths, enemies if visible, structures, and obstacles. "
        "Do not suggest actions."
    )

    payload = {
        "model": model,
        "prompt": prompt,
        "images": [image_b64],
        "stream": False,
    }

    response = requests.post("http://127.0.0.1:11434/api/generate", json=payload, timeout=60)
    response.raise_for_status()
    data = response.json()
    text = (data.get("response") or "").strip()
    if not text:
        raise RuntimeError("Model returned empty description")
    return text


def _softmax(logits):
    shifted = logits - np.max(logits)
    exp = np.exp(shifted)
    denom = np.sum(exp)
    if denom <= 0:
        return exp
    return exp / denom


def _load_labels(labels_path: Path):
    labels = []
    for line in labels_path.read_text(encoding="utf-8").splitlines():
        label = line.strip()
        if label:
            labels.append(label)
    if not labels:
        raise RuntimeError(f"No labels found in {labels_path}")
    return labels


def _tensor_from_image(image_path: Path, input_shape):
    if Image is None or np is None:
        raise RuntimeError("PIL and numpy are required for local model mode")

    size = 224
    if len(input_shape) >= 4 and isinstance(input_shape[-1], int) and input_shape[-1] > 0:
        size = input_shape[-1]

    img = Image.open(image_path).convert("RGB").resize((size, size))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    arr = np.transpose(arr, (2, 0, 1))
    arr = np.expand_dims(arr, axis=0)
    return arr


def _scene_text_from_predictions(predictions):
    terrain = []
    road = []
    enemy = []
    building = []
    obstacle = []
    interactable = []

    for label, score in predictions:
        key = label.lower()
        if key.startswith("terrain_"):
            terrain.append(label.replace("terrain_", ""))
        elif key.startswith("road_"):
            road.append(label.replace("road_", ""))
        elif key.startswith("enemy_"):
            enemy.append(label.replace("enemy_", ""))
        elif key.startswith("building_"):
            building.append(label.replace("building_", ""))
        elif key.startswith("obstacle_"):
            obstacle.append(label.replace("obstacle_", ""))
        elif key.startswith("interactable_"):
            interactable.append(label.replace("interactable_", ""))

    parts = []
    if terrain:
        parts.append(f"Terrain appears {terrain[0]} ahead")
    if road:
        parts.append(f"a road/path feature is {road[0]}")
    if enemy:
        parts.append(f"possible hostile presence: {enemy[0]}")
    if building:
        parts.append(f"structure visible: {building[0]}")
    if obstacle:
        parts.append(f"obstacles nearby: {obstacle[0]}")
    if interactable:
        parts.append(f"possible interactable object: {interactable[0]}")

    if not parts:
        return "Scene captured. Terrain and object classes are uncertain in this frame."

    text = ". ".join(parts)
    if not text.endswith("."):
        text += "."
    return text


def describe_with_local_weights(image_path: Path, weights_path: Path, labels_path: Path, threshold: float):
    if ort is None:
        raise RuntimeError("onnxruntime is not installed. pip install onnxruntime")
    if np is None:
        raise RuntimeError("numpy is not installed. pip install numpy")
    if not weights_path.exists():
        raise RuntimeError(f"Model weights not found: {weights_path}")
    if not labels_path.exists():
        raise RuntimeError(f"Labels file not found: {labels_path}")

    labels = _load_labels(labels_path)
    session = ort.InferenceSession(str(weights_path), providers=["CPUExecutionProvider"])
    input_meta = session.get_inputs()[0]
    input_name = input_meta.name
    input_shape = input_meta.shape

    tensor = _tensor_from_image(image_path, input_shape)
    outputs = session.run(None, {input_name: tensor})
    if not outputs:
        raise RuntimeError("Local model returned no outputs")

    logits = np.array(outputs[0]).reshape(-1)
    probs = _softmax(logits)

    indexed = list(enumerate(probs.tolist()))
    indexed.sort(key=lambda x: x[1], reverse=True)

    predictions = []
    for idx, score in indexed[:8]:
        if idx < len(labels) and score >= threshold:
            predictions.append((labels[idx], score))

    if not predictions and indexed:
        idx, score = indexed[0]
        if idx < len(labels):
            predictions.append((labels[idx], score))

    description = _scene_text_from_predictions(predictions)
    return description, predictions


def _image_features_for_joblib(image_path: Path, bins: int = 16):
    if Image is None or np is None:
        raise RuntimeError("PIL and numpy are required for joblib model mode")

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


def describe_with_joblib_model(image_path: Path, model_dir: Path, args):
    if joblib is None:
        raise RuntimeError("joblib is not installed. pip install joblib")
    if np is None:
        raise RuntimeError("numpy is not installed. pip install numpy")
    if pd is None:
        raise RuntimeError("pandas is not installed. pip install pandas")

    model_path = model_dir / "scene_model.joblib"
    labels_path = model_dir / "labels.txt"
    features_path = model_dir / "feature_columns.json"

    if not model_path.exists():
        raise RuntimeError(f"Trained model not found: {model_path}")
    if not labels_path.exists():
        raise RuntimeError(f"Labels file not found: {labels_path}")
    if not features_path.exists():
        raise RuntimeError(f"Feature columns file not found: {features_path}")

    labels = [line.strip() for line in labels_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    feature_columns = json.loads(features_path.read_text(encoding="utf-8"))
    model = joblib.load(model_path)

    zone = args.zone or "UNKNOWN_ZONE"
    map_id = args.map_id or "0"
    pos_x = float(args.x) if args.x is not None else 0.0
    pos_y = float(args.y) if args.y is not None else 0.0
    facing = float(args.facing) if args.facing is not None else 0.0
    pitch = float(args.pitch) if args.pitch is not None else 0.0
    zoom = float(args.zoom) if args.zoom is not None else 2.6

    row = {
        "pos_x": pos_x,
        "pos_y": pos_y,
        "camera_pitch": pitch,
        "camera_zoom": zoom,
        "facing_sin": float(np.sin(facing)),
        "facing_cos": float(np.cos(facing)),
        f"zone_{zone}": 1,
        f"map_{map_id}": 1,
    }

    img_feat = _image_features_for_joblib(image_path, bins=args.joblib_bins)
    for i, v in enumerate(img_feat.tolist()):
        row[f"img_feat_{i}"] = v

    x_df = pd.DataFrame([row])
    for col in feature_columns:
        if col not in x_df.columns:
            x_df[col] = 0
    x_df = x_df[feature_columns]

    x = x_df.to_numpy(dtype=np.float32)
    y_pred = model.predict(x)[0]

    predictions = []
    for i, flag in enumerate(y_pred.tolist()):
        if flag == 1 and i < len(labels):
            predictions.append((labels[i], 1.0))

    description = _scene_text_from_predictions(predictions)
    if not predictions:
        description = "Scene uncertain from current model output."

    return description, predictions


def build_command_text(description: str) -> str:
    clean = " ".join(description.split())
    return f"/look set {clean}"


def delete_capture_image(image_path: Path) -> bool:
    try:
        image_path.unlink()
        return True
    except FileNotFoundError:
        return False
    except OSError as exc:
        print(f"[LOOK] Warning: failed to delete temporary image {image_path}: {exc}", file=sys.stderr)
        return False


def default_wow_screenshots_dir() -> Optional[Path]:
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "Screenshots"
        if candidate.is_dir():
            return candidate
    return None


def delete_fresh_wow_screenshots(args, since_ts: float) -> int:
    # Note: since_ts/grace are ignored unless --wow-screenshot-only-fresh is set.
    # Default behavior is to wipe ALL WoWScrnShot_*.jpg/.jpeg in the Screenshots
    # directory so the folder doesn't accumulate stream artifacts.
    screenshots_dir = Path(args.wow_screenshots_dir) if args.wow_screenshots_dir else default_wow_screenshots_dir()
    if screenshots_dir is None or not screenshots_dir.is_dir():
        return 0

    only_fresh = getattr(args, "wow_screenshot_only_fresh", False)
    cutoff = since_ts - max(0.0, getattr(args, "wow_screenshot_grace_seconds", 0.0))
    deleted = 0
    for pattern in ("WoWScrnShot_*.jpg", "WoWScrnShot_*.jpeg"):
        for screenshot_path in screenshots_dir.glob(pattern):
            if only_fresh:
                try:
                    if screenshot_path.stat().st_mtime < cutoff:
                        continue
                except FileNotFoundError:
                    continue
            if delete_capture_image(screenshot_path):
                deleted += 1
    return deleted


def run_once(args) -> int:
    started_at = time.time()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    ts = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    image_path = output_dir / f"wow_frame_{ts}.png"
    bridge_txt = output_dir / "look_last_description.txt"

    try:
        capture = capture_wow_frame(output_path=image_path, window_title=args.window_title)

        predictions = []
        if args.model_mode == "ollama":
            description = describe_with_ollama(image_path, args.ollama_model)
        elif args.model_mode == "local":
            description, predictions = describe_with_local_weights(
                image_path=image_path,
                weights_path=Path(args.weights_path),
                labels_path=Path(args.labels_path),
                threshold=args.confidence_threshold,
            )
        elif args.model_mode == "joblib":
            description, predictions = describe_with_joblib_model(
                image_path=image_path,
                model_dir=Path(args.model_dir),
                args=args,
            )
        else:
            description = describe_placeholder(image_path)

        command_text = build_command_text(description)

        payload = {
            "captured_at": dt.datetime.now().isoformat(),
            "image_path": str(image_path),
            "image_retention": "kept" if args.keep_screenshot else "delete_after_processing",
            "capture_mode": capture.mode,
            "width": capture.width,
            "height": capture.height,
            "description": description,
            "look_set_command": command_text,
            "model_mode": args.model_mode,
            "predictions": [
                {"label": label, "score": round(score, 4)} for (label, score) in predictions
            ],
        }

        (output_dir / "look_last.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
        bridge_txt.write_text(description + "\n", encoding="utf-8")

        print("[LOOK] Capture mode:", capture.mode)
        print("[LOOK] Image:", image_path)
        print("[LOOK] Description:", description)
        print("[LOOK] Paste this in WoW:")
        print(command_text)
        return 0
    finally:
        if not args.keep_screenshot and delete_capture_image(image_path):
            print("[LOOK] Deleted temporary image:", image_path)
        if not args.keep_screenshot:
            deleted_jpgs = delete_fresh_wow_screenshots(args, started_at)
            if deleted_jpgs:
                print(f"[LOOK] Deleted {deleted_jpgs} WoW screenshot JPG(s)")


def run_hotkey_loop(args) -> int:
    if keyboard is None:
        print("keyboard package not installed. Install with: pip install keyboard")
        print("Falling back to one-shot capture.")
        return run_once(args)

    print("Accessibility /look prototype hotkey loop started")
    print("Hotkey:", args.hotkey)
    print("Press ESC to quit")

    loop_started_at = time.time()
    last_screenshot_cleanup_at = 0.0
    while True:
        now = time.time()
        if not args.keep_screenshot and now - last_screenshot_cleanup_at >= 0.5:
            deleted_jpgs = delete_fresh_wow_screenshots(args, loop_started_at)
            if deleted_jpgs:
                print(f"[LOOK] Deleted {deleted_jpgs} WoW screenshot JPG(s)")
            last_screenshot_cleanup_at = now

        if keyboard.is_pressed("esc"):
            print("Exiting hotkey loop")
            break
        if keyboard.is_pressed(args.hotkey):
            run_once(args)
            time.sleep(0.8)
        time.sleep(0.05)
    return 0


def parse_args(argv: list[str]):
    parser = argparse.ArgumentParser(description="WoW accessibility /look capture prototype")
    parser.add_argument("--window-title", default="World of Warcraft", help="Window title match")
    parser.add_argument("--output-dir", default="tools/look_accessibility/temp", help="Output directory")
    parser.add_argument("--model-mode", choices=["placeholder", "ollama", "local", "joblib"], default="placeholder")
    parser.add_argument("--ollama-model", default="llava:latest", help="Ollama vision model name")
    parser.add_argument(
        "--weights-path",
        default="tools/look_accessibility/model/tiny_scene.onnx",
        help="Path to local ONNX weights",
    )
    parser.add_argument(
        "--labels-path",
        default="tools/look_accessibility/model/labels.txt",
        help="Path to class labels",
    )
    parser.add_argument(
        "--confidence-threshold",
        type=float,
        default=0.20,
        help="Minimum probability threshold for reported classes",
    )
    parser.add_argument("--model-dir", default="tools/look_accessibility/model", help="Directory for trained joblib model artifacts")
    parser.add_argument("--zone", default="", help="World zone name for joblib model telemetry")
    parser.add_argument("--map-id", default="", help="Map ID for joblib model telemetry")
    parser.add_argument("--x", type=float, default=None, help="Player normalized map x for joblib mode")
    parser.add_argument("--y", type=float, default=None, help="Player normalized map y for joblib mode")
    parser.add_argument("--facing", type=float, default=None, help="Facing radians for joblib mode")
    parser.add_argument("--pitch", type=float, default=None, help="Camera pitch for joblib mode")
    parser.add_argument("--zoom", type=float, default=None, help="Camera zoom for joblib mode")
    parser.add_argument("--joblib-bins", type=int, default=16, help="Histogram bins used by joblib feature extractor")
    parser.add_argument("--hotkey", default="ctrl+shift+l", help="Global hotkey for capture loop")
    parser.add_argument("--watch", action="store_true", help="Run hotkey loop")
    parser.add_argument("--keep-screenshot", action="store_true", help="Keep captured image files after processing")
    parser.add_argument("--wow-screenshots-dir", default="", help="WoW Screenshots directory for cleanup")
    parser.add_argument(
        "--wow-screenshot-only-fresh",
        action="store_true",
        help="Only delete WoW screenshot JPGs newer than the grace window (default: delete all)",
    )
    parser.add_argument(
        "--wow-screenshot-grace-seconds",
        type=float,
        default=5.0,
        help="With --wow-screenshot-only-fresh: delete JPGs modified this many seconds before capture start or later",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.watch:
        return run_hotkey_loop(args)
    return run_once(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
