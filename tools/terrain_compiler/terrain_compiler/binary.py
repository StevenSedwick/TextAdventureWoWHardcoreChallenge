from __future__ import annotations

from dataclasses import dataclass
import struct
from typing import Iterator


@dataclass
class Chunk:
    tag: str
    size: int
    offset: int
    data: bytes


def iter_chunks(blob: bytes, start: int = 0, end: int | None = None) -> Iterator[Chunk]:
    """Iterate WoW chunked-binary records.

    WoW map chunks are encoded as <tag:4><size:u32><payload:size>.
    """
    cursor = start
    limit = len(blob) if end is None else min(len(blob), end)

    while cursor + 8 <= limit:
        # WoW chunk tags are stored as little-endian FOURCC (e.g. b"REVM" -> "MVER").
        raw_tag = blob[cursor : cursor + 4]
        tag = raw_tag[::-1].decode("latin1", errors="replace")
        size = struct.unpack_from("<I", blob, cursor + 4)[0]
        payload_start = cursor + 8
        payload_end = payload_start + size
        if payload_end > limit:
            break

        yield Chunk(tag=tag, size=size, offset=cursor, data=blob[payload_start:payload_end])
        cursor = payload_end


def unpack_f32_array(blob: bytes, max_count: int | None = None) -> list[float]:
    count = len(blob) // 4
    if max_count is not None:
        count = min(count, max_count)
    if count <= 0:
        return []
    return list(struct.unpack_from(f"<{count}f", blob, 0))
