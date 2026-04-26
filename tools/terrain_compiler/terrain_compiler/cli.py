from __future__ import annotations

import argparse
from pathlib import Path

from .exporter_lua import write_zone_lua
from .pipeline import compile_zone


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Compile WoW Classic WDT/ADT terrain into DFMode Lua tables.")
    parser.add_argument("--input-root", required=True, help="Root folder containing extracted map directories.")
    parser.add_argument("--map", required=True, help="Map folder name, e.g. Azeroth or Kalimdor.")
    parser.add_argument("--zone-key", required=True, help="zoneKey for output (example: elwynn_forest).")
    parser.add_argument("--output", required=True, help="Output Lua file path, e.g. DFMode_TerrainData.lua")
    parser.add_argument("--sample-stride", type=int, default=4, help="Height-grid sampling stride (default: 4).")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    zone = compile_zone(
        input_root=Path(args.input_root),
        map_name=args.map,
        zone_key=args.zone_key,
        sample_stride=max(1, int(args.sample_stride)),
    )

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    write_zone_lua(out_path, zone)

    print(f"Wrote {out_path}")
    print(f"Chunks: {len(zone.chunks)} | markers: {len(zone.markers)} | tiles: {len(zone.tiles_present)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
