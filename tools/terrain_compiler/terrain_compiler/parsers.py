from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import struct

from .binary import iter_chunks, unpack_f32_array
from .mathutils import estimate_slope_grid, sample_grid
from .models import ChunkTerrain, ObjectMarker


ADT_VARIANT_NAME_RE = re.compile(
    r"^(?P<map>.+)_(?P<x>\d+)_(?P<y>\d+)(?:_(?P<kind>[a-z]+)(?P<index>\d+))?\.adt$",
    re.IGNORECASE,
)


@dataclass
class ADTFileRef:
    map_name: str
    tile_x: int
    tile_y: int
    variant_kind: str | None
    variant_index: int | None


@dataclass
class ParsedADT:
    map_name: str
    tile_x: int
    tile_y: int
    source_file: str
    variant_kind: str | None
    variant_index: int | None
    chunks: list[ChunkTerrain]
    markers: list[ObjectMarker]


def parse_adt_filename(path: Path) -> ADTFileRef:
    match = ADT_VARIANT_NAME_RE.match(path.name)
    if not match:
        raise ValueError(
            f"Expected ADT name '<map>_<x>_<y>.adt' or '<map>_<x>_<y>_<kind><n>.adt', got: {path.name}"
        )

    map_name = match.group("map")
    tile_x = int(match.group("x"))
    tile_y = int(match.group("y"))
    variant_kind = match.group("kind")
    variant_index_raw = match.group("index")
    variant_index = int(variant_index_raw) if variant_index_raw else None
    return ADTFileRef(
        map_name=map_name,
        tile_x=tile_x,
        tile_y=tile_y,
        variant_kind=variant_kind,
        variant_index=variant_index,
    )


def parse_wdt_tiles_present(path: Path) -> list[list[int]]:
    blob = path.read_bytes()
    for chunk in iter_chunks(blob):
        if chunk.tag == "MAIN":
            data = chunk.data
            out: list[list[int]] = []
            entry_size = 8
            total = min(len(data) // entry_size, 64 * 64)
            for idx in range(total):
                flags = struct.unpack_from("<I", data, idx * entry_size)[0]
                if flags & 0x1:
                    tx = idx % 64
                    ty = idx // 64
                    out.append([tx, ty])
            return out
    return []


def _classify_texture(texture_name: str) -> str | None:
    t = texture_name.lower()
    if "road" in t or "path" in t or "cobble" in t:
        return "road"
    if "snow" in t or "ice" in t or "frost" in t:
        return "snow"
    if "rock" in t or "stone" in t or "cliff" in t:
        return "rock"
    if "grass" in t or "moss" in t or "dirt" in t:
        return "grass"
    if "sand" in t or "desert" in t:
        return "sand"
    if "water" in t or "river" in t:
        return "water"
    return None


def _parse_mcnk_subchunks(
    payload: bytes,
    tile_x: int,
    tile_y: int,
    sample_stride: int,
    texture_names: list[str],
) -> tuple[ChunkTerrain | None, list[ObjectMarker]]:
    if len(payload) < 128:
        return None, []

    chunk_x = struct.unpack_from("<I", payload, 4)[0]
    chunk_y = struct.unpack_from("<I", payload, 8)[0]

    world_x = world_y = world_z = None
    for offset in (0x60, 0x68, 0x70):
        if offset + 12 <= len(payload):
            x, y, z = struct.unpack_from("<fff", payload, offset)
            if -50000.0 < x < 50000.0 and -50000.0 < y < 50000.0 and -50000.0 < z < 50000.0:
                world_x, world_y, world_z = x, y, z
                break

    heights_raw: list[float] = []
    has_water = False
    water_level: float | None = None
    texture_label: str | None = None

    sub_start = 128
    for sub in iter_chunks(payload, start=sub_start):
        if sub.tag == "MCVT":
            heights_raw = unpack_f32_array(sub.data, max_count=145)
            if world_z is not None and heights_raw:
                heights_raw = [h + world_z for h in heights_raw]
        elif sub.tag == "MCLY" and len(sub.data) >= 16:
            texture_id = struct.unpack_from("<I", sub.data, 0)[0]
            if 0 <= texture_id < len(texture_names):
                texture_label = _classify_texture(texture_names[texture_id])
        elif sub.tag in ("MCLQ", "MH2O"):
            has_water = True
            if len(sub.data) >= 4:
                water_level = struct.unpack_from("<f", sub.data, 0)[0]

    sampled_heights = sample_grid(heights_raw, stride=sample_stride) if heights_raw else []
    sampled_slope = estimate_slope_grid(sampled_heights)

    terrain = ChunkTerrain(
        tile_x=tile_x,
        tile_y=tile_y,
        chunk_x=chunk_x,
        chunk_y=chunk_y,
        world_x=world_x,
        world_y=world_y,
        world_z=world_z,
        sampled_heights=sampled_heights,
        sampled_slope=sampled_slope,
        has_water=has_water,
        water_level=water_level,
        texture_label=texture_label,
    )
    return terrain, []


def _parse_markers(chunk_tag: str, data: bytes) -> list[ObjectMarker]:
    out: list[ObjectMarker] = []
    if chunk_tag == "MDDF":
        entry = 36
        for i in range(0, len(data) - entry + 1, entry):
            obj_id = struct.unpack_from("<I", data, i)[0]
            x, y, z = struct.unpack_from("<fff", data, i + 4)
            out.append(ObjectMarker(kind="doodad", id=obj_id, x=x, y=y, z=z))
    elif chunk_tag == "MODF":
        entry = 64
        for i in range(0, len(data) - entry + 1, entry):
            obj_id = struct.unpack_from("<I", data, i)[0]
            x, y, z = struct.unpack_from("<fff", data, i + 8)
            out.append(ObjectMarker(kind="wmo", id=obj_id, x=x, y=y, z=z))
    return out


def parse_adt(path: Path, sample_stride: int = 4) -> ParsedADT:
    file_ref = parse_adt_filename(path)
    map_name = file_ref.map_name
    tile_x = file_ref.tile_x
    tile_y = file_ref.tile_y

    blob = path.read_bytes()
    texture_names: list[str] = []
    chunks: list[ChunkTerrain] = []
    markers: list[ObjectMarker] = []

    # First pass: grab texture string table for layer labeling.
    for top in iter_chunks(blob):
        if top.tag == "MTEX":
            names = [n.decode("latin1", errors="ignore") for n in top.data.split(b"\x00") if n]
            texture_names.extend(names)

    for top in iter_chunks(blob):
        if top.tag == "MCNK":
            seq_cx = len(chunks) % 16
            seq_cy = len(chunks) // 16
            parsed, _ = _parse_mcnk_subchunks(top.data, tile_x, tile_y, sample_stride, texture_names)
            if parsed:
                parsed.chunk_x = seq_cx
                parsed.chunk_y = seq_cy
                chunks.append(parsed)
        elif top.tag in ("MDDF", "MODF"):
            markers.extend(_parse_markers(top.tag, top.data))

    return ParsedADT(
        map_name=map_name,
        tile_x=tile_x,
        tile_y=tile_y,
        source_file=path.name,
        variant_kind=file_ref.variant_kind,
        variant_index=file_ref.variant_index,
        chunks=chunks,
        markers=markers,
    )
