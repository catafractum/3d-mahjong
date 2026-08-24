#!/usr/bin/env python3
"""Regenerate the curated 3-D layouts while preserving level metadata."""

import json
from pathlib import Path


DATA_PATH = Path(__file__).parents[1] / "data" / "levels_new.json"


def centered_square(size, y, inset=0):
    lo = (7 - size) // 2 + inset
    hi = lo + size - inset * 2
    return {(x, y, z) for x in range(lo, hi) for z in range(lo, hi)}


def ring(size, y, inset=0):
    cells = centered_square(size, y, inset)
    xs = [p[0] for p in cells]
    zs = [p[2] for p in cells]
    lo_x, hi_x, lo_z, hi_z = min(xs), max(xs), min(zs), max(zs)
    return {p for p in cells if p[0] in (lo_x, hi_x) or p[2] in (lo_z, hi_z)}


def diamond(radius, y, center=3):
    return {(x, y, z) for x in range(7) for z in range(7)
            if abs(x - center) + abs(z - center) <= radius}


def cross(radius, y, thickness=0):
    return {(x, y, z) for x in range(7) for z in range(7)
            if abs(x - 3) <= thickness and abs(z - 3) <= radius
            or abs(z - 3) <= thickness and abs(x - 3) <= radius}


def diamond6(y):
    return {(x, y, z) for x in range(6) for z in range(6)
            if abs(x - 2.5) + abs(z - 2.5) <= 4}


def cross6(y):
    return {(x, y, z) for x in range(6) for z in range(6)
            if x in (2, 3) or z in (2, 3)}


def box(xs, ys, zs):
    return {(x, y, z) for x in xs for y in ys for z in zs}


def shell(xs, ys, zs):
    xs, ys, zs = tuple(xs), tuple(ys), tuple(zs)
    return {(x, y, z) for x in xs for y in ys for z in zs
            if x in (xs[0], xs[-1]) or y in (ys[0], ys[-1]) or z in (zs[0], zs[-1])}


def make_easy(slot):
    layouts = [
        ring(5, 0) | ring(3, 1) | {(3, 2, 2), (3, 2, 4)},
        {(x, y, z) for x in (1, 2, 4, 5) for z in (1, 2, 4, 5) for y in range(2)}
        | {(2, 2, 2), (4, 2, 4)},
        cross(2, 0) | cross(1, 1) | {(3, 2, 2), (3, 2, 4)},
        {(x, y, z) for y in range(4) for x in range(1 + y, 6 - y) for z in (2, 4)}
        | {(2, 1, 3), (4, 1, 3)},
        diamond(2, 0) | cross(2, 1) | cross(1, 2),
        ring(5, 0) | ring(3, 1) | {(3, 2, 3), (3, 3, 3)},
        {(x, y, z) for y in range(4) for x in range(1 + y // 2, 6 - y // 2)
         for z in (1 + y, 5 - y) if 1 + y <= 5 - y},
        ring(3, 0) | ring(3, 1) | {(2, y, 2) for y in range(2, 5)}
        | {(4, y, 4) for y in range(2, 5)},
        cross(2, 0) | {(x, 1, z) for x, z in ((2, 2), (2, 4), (4, 2), (4, 4))}
        | {(3, 2, 2), (3, 2, 4), (2, 3, 3), (4, 3, 3)},
        ring(5, 0) | {(x, 1, z) for x in (2, 4) for z in (2, 4)}
        | {(2, 2, 2), (4, 2, 4)},
        {(x, 0, z) for x in range(1, 6) for z in (2, 4)}
        | {(x, 1, z) for x in range(2, 5) for z in (2, 4)}
        | {(3, 2, 2), (3, 2, 4)},
        {(x, 0, z) for z in range(1, 6) for x in range(1, z + 1) if x <= 5}
        | cross(1, 1) | {(3, 2, 3)},
    ]
    return layouts[slot]


def make_medium(slot):
    variants = [
        box(range(1, 5), range(4), range(1, 5)),                         # 4³ cube
        box(range(1, 6), range(4), range(2, 5)),                         # broad brick
        box(range(0, 3), range(4), range(1, 4)) | box(range(3, 6), range(4), range(3, 6)),
        box(range(1, 5), range(4), range(0, 5)),                         # tall slab
        shell(range(1, 6), range(5), range(1, 6)),                       # hollow cube
        box(range(2, 4), range(5), range(6)) | box(range(6), range(5), range(2, 4)),
        box(range(0, 2), range(5), range(6)) | box(range(4, 6), range(5), range(6)),
        box(range(1, 5), range(6), range(1, 5)) - box(range(2, 4), range(1, 5), range(2, 4)),
        box(range(6), range(4), range(2)) | box(range(6), range(4), range(4, 6)),
        box(range(0, 3), range(5), range(0, 3)) | box(range(3, 6), range(5), range(3, 6)),
        shell(range(6), range(5), range(6)),
        box(range(6), range(4), range(6)) - box(range(2, 4), range(4), range(2, 4)),
    ]
    return variants[slot]


def make_hard(slot):
    layouts = [
        box(range(7), range(5), range(7)) - box(range(2, 5), range(1, 4), range(2, 5)),
        box(range(6), range(5), range(6)),                               # solid 6×5×6
        shell(range(6), range(6), range(6)) | box(range(2, 4), range(6), range(2, 4)),
        box(range(6), range(6), range(6)) - box(range(2, 4), range(6), range(2, 4)),
        box(range(0, 3), range(6), range(6)) | box(range(3, 6), range(6), range(0, 3)),
        box(range(6), range(6), range(2)) | box(range(6), range(6), range(4, 6)) | box(range(2, 4), range(6), range(2, 4)),
        shell(range(7), range(7), range(7)) | box(range(2, 5), range(2, 5), range(2, 5)),
        box(range(6), range(6), range(6)),                               # Rubik-style solid cube
        shell(range(6), range(6), range(6)) | box(range(6), range(2, 4), range(2, 4)),
        box(range(3), range(6), range(3)) | box(range(3, 6), range(6), range(3, 6)) | box(range(2, 4), range(6), range(2, 4)),
        box(range(6), range(6), range(6)) - box(range(1, 5), range(2, 4), range(1, 5)),
        box(range(7), range(7), range(5)) - box(range(2, 5), range(1, 6), range(1, 4)),
    ]
    return layouts[slot]


def normalize_even(cells):
    cells = set(cells)
    if len(cells) % 2:
        # Remove a deterministic, exposed cell so the silhouette remains playable.
        cells.remove(sorted(cells, key=lambda p: (p[1], p[2], p[0]))[0])
    return sorted(cells, key=lambda p: (p[1], p[2], p[0]))


def assign_icons(cells, difficulty):
    occupancy = set(cells)
    sequence = []
    directions = ((1, 0), (-1, 0), (0, 1), (0, -1))
    while occupancy:
        free = []
        for x, y, z in occupancy:
            sides = [(dx, dz) for dx, dz in directions if (x + dx, y, z + dz) not in occupancy]
            if any(a[0] + b[0] or a[1] + b[1] for i, a in enumerate(sides) for b in sides[i + 1:]):
                free.append((x, y, z))
        free.sort(key=lambda p: (p[1], p[2], p[0]))
        if len(free) < 2:
            raise ValueError("generated layout has no complete removal sequence")
        pair = free[:2]
        occupancy.difference_update(pair)
        sequence.append(pair)
    desired = len(cells) // 4
    limits = {"easy": (4, 8), "medium": (6, 12), "hard": (8, 16)}[difficulty]
    pool_size = max(limits[0], min(desired, limits[1], 16))
    by_position = {}
    for index, pair in enumerate(sequence):
        for position in pair:
            by_position[position] = index % pool_size
    return [by_position[position] for position in cells]


def main():
    document = json.loads(DATA_PATH.read_text())
    for level in document["levels"]:
        slot = int(level["slot"])
        difficulty = level["difficulty"]
        cells = {"easy": make_easy, "medium": make_medium, "hard": make_hard}[difficulty](slot)
        ordered = normalize_even(cells)
        level["tiles"] = [list(p) for p in ordered]
        level["tile_icons"] = assign_icons(ordered, difficulty)
    DATA_PATH.write_text(json.dumps(document, indent="\t") + "\n")


if __name__ == "__main__":
    main()
