from __future__ import annotations

from pathlib import Path

from .models import ZoneTerrain
from .parsers import parse_adt, parse_adt_filename, parse_wdt_tiles_present


def _variant_sort_key(path: Path) -> tuple[int, int]:
    """Sort ADT files so base tiles are considered before split variants."""
    meta = parse_adt_filename(path)
    if meta.variant_kind is None:
        return (0, 0)
    return (1, meta.variant_index or 0)


def _merge_chunk(existing, incoming):
    # Keep whichever version has more complete geometry, while merging optional fields.
    ex_h = len(existing.sampled_heights)
    in_h = len(incoming.sampled_heights)
    if in_h > ex_h:
        existing.sampled_heights = incoming.sampled_heights
        existing.sampled_slope = incoming.sampled_slope

    if existing.world_x is None and incoming.world_x is not None:
        existing.world_x = incoming.world_x
    if existing.world_y is None and incoming.world_y is not None:
        existing.world_y = incoming.world_y
    if existing.world_z is None and incoming.world_z is not None:
        existing.world_z = incoming.world_z

    if incoming.has_water:
        existing.has_water = True
    if existing.water_level is None and incoming.water_level is not None:
        existing.water_level = incoming.water_level
    if existing.texture_label is None and incoming.texture_label is not None:
        existing.texture_label = incoming.texture_label


def _merge_tile_parsed(parsed_list):
    chunk_by_key = {}
    marker_set = set()
    merged_markers = []

    for parsed in parsed_list:
        for chunk in parsed.chunks:
            key = (chunk.chunk_x, chunk.chunk_y)
            existing = chunk_by_key.get(key)
            if existing is None:
                chunk_by_key[key] = chunk
            else:
                _merge_chunk(existing, chunk)

        for marker in parsed.markers:
            marker_key = (
                marker.kind,
                marker.id,
                round(marker.x, 3),
                round(marker.y, 3),
                round(marker.z, 3),
            )
            if marker_key not in marker_set:
                marker_set.add(marker_key)
                merged_markers.append(marker)

    merged_chunks = list(chunk_by_key.values())
    merged_chunks.sort(key=lambda c: (c.tile_y, c.tile_x, c.chunk_y, c.chunk_x))
    return merged_chunks, merged_markers


def compile_zone(input_root: Path, map_name: str, zone_key: str, sample_stride: int = 4) -> ZoneTerrain:
    map_dir = input_root / map_name
    if not map_dir.exists():
        raise FileNotFoundError(f"Map directory not found: {map_dir}")

    wdt_path = map_dir / f"{map_name}.wdt"
    tiles_present = parse_wdt_tiles_present(wdt_path) if wdt_path.exists() else []

    chunks = []
    markers = []
    tile_min_x = tile_min_y = 999
    tile_max_x = tile_max_y = -999

    adt_groups = {}
    for adt in sorted(map_dir.glob(f"{map_name}_*.adt")):
        meta = parse_adt_filename(adt)
        if meta.map_name != map_name:
            continue
        key = (meta.tile_x, meta.tile_y)
        adt_groups.setdefault(key, []).append(adt)

    for (tile_x, tile_y), files in sorted(adt_groups.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        parsed_parts = []
        for adt in sorted(files, key=_variant_sort_key):
            parsed_parts.append(parse_adt(adt, sample_stride=sample_stride))

        tile_chunks, tile_markers = _merge_tile_parsed(parsed_parts)
        chunks.extend(tile_chunks)
        markers.extend(tile_markers)
        tile_min_x = min(tile_min_x, tile_x)
        tile_min_y = min(tile_min_y, tile_y)
        tile_max_x = max(tile_max_x, tile_x)
        tile_max_y = max(tile_max_y, tile_y)

    if tile_max_x < tile_min_x:
        tile_min_x = tile_min_y = tile_max_x = tile_max_y = 0

    map_bounds = {
        "tileMin": [tile_min_x, tile_min_y],
        "tileMax": [tile_max_x, tile_max_y],
        "chunkMin": [tile_min_x * 16, tile_min_y * 16],
        "chunkMax": [tile_max_x * 16 + 15, tile_max_y * 16 + 15],
    }

    return ZoneTerrain(
        zone_key=zone_key,
        map_name=map_name,
        map_bounds=map_bounds,
        tiles_present=tiles_present,
        chunks=chunks,
        markers=markers,
    )
