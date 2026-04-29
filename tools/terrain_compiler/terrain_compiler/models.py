from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class ChunkTerrain:
    tile_x: int
    tile_y: int
    chunk_x: int
    chunk_y: int
    world_x: float | None
    world_y: float | None
    world_z: float | None
    sampled_heights: list[list[float]]
    sampled_slope: list[list[float]]
    has_water: bool = False
    water_level: float | None = None
    texture_label: str | None = None


@dataclass
class ObjectMarker:
    kind: str
    id: int
    x: float
    y: float
    z: float


@dataclass
class ZoneTerrain:
    zone_key: str
    map_name: str
    map_bounds: dict
    tiles_present: list[list[int]] = field(default_factory=list)
    chunks: list[ChunkTerrain] = field(default_factory=list)
    markers: list[ObjectMarker] = field(default_factory=list)
