from __future__ import annotations

import math


def sample_grid(heights_145: list[float], stride: int = 4) -> list[list[float]]:
    """Sample WoW 145-point MCVT field into a regular 9x9-ish raster.

    MCVT holds 145 values for a 17x17/16x16 interleaved pattern. This function
    approximates it as a 17x17 matrix by row-major indexing and downsamples.
    """
    if len(heights_145) < 145:
        return []

    side = 17
    dense: list[list[float]] = []
    idx = 0
    for _ in range(side):
        row = heights_145[idx : idx + side]
        if len(row) < side:
            row = row + [row[-1] if row else 0.0] * (side - len(row))
        dense.append(row)
        idx += side

    sampled: list[list[float]] = []
    for y in range(0, side, max(1, stride)):
        sampled.append([round(dense[y][x], 3) for x in range(0, side, max(1, stride))])
    return sampled


def estimate_slope_grid(height_grid: list[list[float]]) -> list[list[float]]:
    if not height_grid or not height_grid[0]:
        return []

    rows = len(height_grid)
    cols = len(height_grid[0])
    slope: list[list[float]] = [[0.0 for _ in range(cols)] for _ in range(rows)]

    for y in range(rows):
        for x in range(cols):
            left = height_grid[y][x - 1] if x > 0 else height_grid[y][x]
            right = height_grid[y][x + 1] if x + 1 < cols else height_grid[y][x]
            up = height_grid[y - 1][x] if y > 0 else height_grid[y][x]
            down = height_grid[y + 1][x] if y + 1 < rows else height_grid[y][x]

            dzdx = (right - left) * 0.5
            dzdy = (down - up) * 0.5
            slope[y][x] = round(math.sqrt(dzdx * dzdx + dzdy * dzdy), 3)

    return slope
