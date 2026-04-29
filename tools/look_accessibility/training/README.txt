World-Conditioned /look Training Pipeline

This pipeline trains a lightweight neural model using:
- World telemetry (zone, map, x/y, facing, pitch, zoom)
- Screenshot features (RGB histogram + edge-density features)
- Multi-label scene tags (terrain_*, road_*, enemy_*, obstacle_*, building_*, interactable_*)

Files:
- dataset_template.csv: required dataset schema
- collect_dataset.py: interactive collector (capture + telemetry + labels -> CSV)
- train_scene_model.py: train + evaluate + save model artifacts
- predict_scene_model.py: run inference and print /look set text
- requirements-training.txt: Python package requirements

Quick Start:
1) Create a dataset CSV based on dataset_template.csv and point image_path to local screenshots.
2) Install requirements:
   pip install -r tools/look_accessibility/training/requirements-training.txt
3) Train:
   python tools/look_accessibility/training/train_scene_model.py --dataset tools/look_accessibility/training/my_dataset.csv --out-dir tools/look_accessibility/model
4) Predict from one frame + telemetry:
   python tools/look_accessibility/training/predict_scene_model.py --model-dir tools/look_accessibility/model --image tools/look_accessibility/temp/wow_frame_20260428_120000.png --zone "Elwynn Forest" --map-id 1429 --x 0.42 --y 0.68 --facing 1.57 --pitch 0.15 --zoom 2.6

Collector workflow (live Classic Era focus):
1) Start collector:
   python tools/look_accessibility/training/collect_dataset.py --workspace-root . --count 1
2) Collector captures one frame.
3) In WoW run:
   /ta look telemetry
4) Paste the LOOK_TELEMETRY line into collector prompt.
5) Enter label tags + description.
6) Collector appends one row to collected_dataset.csv.

Tip: repeat with --count 20 for a quick batch.

Live source tagging:
- Collector writes source_env for every sample.
- Default value is live_classic_era.
- Override only if needed:
   python tools/look_accessibility/training/collect_dataset.py --workspace-root . --source-env live_classic_era

In-game preselected labels (faster collection):
1) In WoW choose labels once:
   /ta look labels preset town
   or /ta look labels add terrain_road
2) Export telemetry:
   /ta look telemetry
3) Collector auto-reads labels=... from telemetry.
4) Press Enter at collector tag prompt to keep auto labels.

Hotkey batch collector loop:
1) Run:
   python tools/look_accessibility/training/collect_dataset.py --workspace-root . --watch --hotkey ctrl+shift+k
2) Press Ctrl+Shift+K to capture each sample.
3) For each sample, paste /ta look telemetry output and labels.
4) Press ESC to stop collection.

Video-to-frames collector (fast bulk labeling):
1) Record gameplay video in live Classic Era.
2) Optionally copy one telemetry snapshot from game:
   /ta look telemetry
3) Extract every Nth frame and append one CSV row per frame:
   python tools/look_accessibility/training/collect_from_video.py --video C:/captures/wow_run.mp4 --every-n-frames 20 --labels terrain_road;safe --description "Road traversal segment"
4) Optional telemetry autofill for zone/map/position/camera and labels:
   python tools/look_accessibility/training/collect_from_video.py --video C:/captures/wow_run.mp4 --every-n-frames 20 --telemetry-line "LOOK_TELEMETRY zone=Elwynn_Forest map=1429 x=0.42 y=0.68 facing=1.57 pitch=0.15 zoom=2.6 labels=terrain_road;safe"

Notes for video mode:
- This mode applies the same labels to every extracted frame in that run.
- Use shorter clips per scene/context so frame labels stay accurate.
- source_env defaults to live_classic_era.

Live joblib inference mode (trained artifacts):
1) Ensure model dir contains scene_model.joblib, labels.txt, feature_columns.json.
2) Run:
   python tools/look_accessibility/look_capture_service.py --model-mode joblib --model-dir tools/look_accessibility/model --zone "Elwynn Forest" --map-id 1429 --x 0.42 --y 0.68 --facing 1.57 --pitch 0.15 --zoom 2.6
3) Script prints a /look set line for in-game paste.

Artifacts:
- scene_model.joblib
- labels.txt
- feature_columns.json
- metrics.json

Notes:
- This pipeline is read-only and does not automate gameplay.
- This model predicts likely scene tags from world context + image descriptors.
- Dynamic entities are harder than static terrain; collect many combat/non-combat examples for enemy_* labels.
