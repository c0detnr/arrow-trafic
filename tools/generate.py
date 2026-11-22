"""Reverse-placement level generator. See --help for options."""
import argparse
import csv
from functools import lru_cache
import hashlib
import json
import multiprocessing
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arrowlib import COLORS, DIRS, Level, SolverLimit, arrow_cells, arrow_path, validate  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRIALS = 200
TIME_LIMIT = 20.0  # seconds per level; hit only as a safety net (breaks determinism if it fires)


@lru_cache(maxsize=None)
def placements(w, h, lens):
    def mask(cells):
        return sum(1 << (y * w + x) for x, y in cells)

    geo = []
    lengths = sorted(set(lens))
    for x in range(w):
        for y in range(h):
            for dr in DIRS:
                for ln in lengths:
                    a = {"x": x, "y": y, "dir": dr, "len": ln}
                    cs = arrow_cells(a)
                    if all(0 <= cx < w and 0 <= cy < h for cx, cy in cs):
                        geo.append((a, mask(cs), mask(arrow_path(a, w, h)), lens.count(ln) * 0.5, 0))
    return geo


def place_arrows(rng, w, h, n, lens=(2, 2, 3, 3, 4)):
    """Each new arrow's head path must be clear, so reverse placement is a solution."""
    geo = placements(w, h, tuple(lens))
    arrows = []
    for _ in range(n):
        if not geo:
            return None
        # prefer arrows that block already placed ones (interlocking), and common lengths
        a, cs, ps, _, _ = max(geo, key=lambda g: g[4] + g[3] + rng.random() * 2)
        arrows.append(dict(a))
        if len(arrows) < n:
            geo = [(g, cells, path, weight, min(blocks + bool(cells & ps), 2))
                   for g, cells, path, weight, blocks in geo if not cs & (cells | path)]
    return arrows


def make_queue(rng, colors_in_order, pocket, swaps):
    """Start from the solution-order colors, then random moves that keep the
    fixed solution order from overflowing the pocket."""
    def ok(q):
        qi, pk = 0, []
        for c in colors_in_order:
            if q[qi] == c:
                qi += 1
            else:
                if len(pk) >= pocket:
                    return False
                pk.append(c)
            while qi < len(q) and q[qi] in pk:
                pk.remove(q[qi])
                qi += 1
        return True

    q = list(colors_in_order)
    for _ in range(swaps):
        i, j = rng.randrange(len(q)), rng.randrange(len(q))
        q2 = q[:]
        q2.insert(j, q2.pop(i))
        if ok(q2):
            q = q2
    return q


def candidate(rng, w, h, n, ncol, pocket, minority=None):
    arrows = None
    while arrows is None:
        arrows = place_arrows(rng, w, h, n)
    palette = rng.sample(COLORS, ncol)
    if minority is None:
        cols = palette + [rng.choice(palette) for _ in range(n - ncol)]
    else:
        cols = [palette[0]] * (n - minority) + palette[1:]
        cols += [rng.choice(palette[1:]) for _ in range(minority - ncol + 1)]
    rng.shuffle(cols)
    for a, c in zip(arrows, cols):
        a["color"] = c
    exit_order = list(range(n))[::-1]
    swaps = rng.randint(0, 4 * n)
    queue = make_queue(rng, [cols[i] for i in exit_order], pocket, swaps)
    return {"id": 0, "w": w, "h": h, "pocket": pocket, "arrows": arrows, "queue": queue}


def build(seed, w, h, n, ncol, pocket, target, max_win=1.0, require_loss=False,
          tries=60, *, time_limit=TIME_LIMIT, tolerance=0.0, minority=None):
    """Generate `tries` candidates, return the solvable one with random win rate closest to target."""
    rng = random.Random(seed)
    best, t0 = None, time.monotonic()
    for k in range(tries):
        if time_limit is not None and time.monotonic() - t0 > time_limit:
            print(f"  warn: time limit hit at candidate {k}", file=sys.stderr)
            break
        d = candidate(rng, w, h, n, ncol, pocket, minority)
        lv = Level(d)
        win = lv.random_play(TRIALS, random.Random(seed * 7919 + k))
        if win > max_win or (require_loss and win >= 1.0):
            continue
        try:
            order, _ = lv.solve(limit=500_000)
        except SolverLimit:
            continue
        if order is None:
            continue
        err = abs(win - target)
        if best is None or err < best[0]:
            best = (err, d, win)
        if err <= tolerance:
            break
    return best and (best[1], best[2])


def lerp(a, b, t):
    return a + (b - a) * t


def proto_specs():
    # (w, h, n, colors, pocket, target_random_win)
    return [
        (4, 5, 4, 2, 4, 1.00), (5, 6, 6, 2, 4, 0.95), (5, 6, 7, 3, 4, 0.85), (5, 7, 8, 3, 3, 0.75),
        (6, 7, 9, 3, 3, 0.62), (6, 7, 10, 3, 3, 0.50), (6, 8, 12, 3, 3, 0.40), (6, 8, 13, 4, 3, 0.30),
        (6, 8, 14, 4, 3, 0.22), (6, 8, 16, 4, 3, 0.15),
    ]


def levels_specs(count=1000):
    out = []
    for i in range(count):
        block_start = i - i % 10
        phase = i % 10
        if i < 50:
            size = lerp(0, 0.8, i / 49)
            base = lerp(0.92, 0.16, block_start / 50)
        else:
            size = lerp(0.8, 1, min((i - 49) / 250, 1))
            base = lerp(0.16, 0.055, min((block_start - 50) / 940, 1))
        target = base * (0.2 if phase == 9 else lerp(1, 0.65, phase / 8))
        out.append((round(lerp(5, 8, size)), round(lerp(6, 11, size)), round(lerp(9, 30, size)),
                    round(lerp(2, 5, size)), 4 if i < 30 else 3, target))
    return out


def build_set(specs, base_seed, require_loss, monotone):
    levels, prev = [], 1.0
    for idx, (w, h, n, ncol, pocket, target) in enumerate(specs):
        seed = base_seed * 1000 + idx
        res = None
        for retry in range(6):  # fresh candidate batches until one fits under the curve
            res = build(seed + retry * 100_003, w, h, n, ncol, pocket, target,
                        max_win=prev if monotone else 1.0, require_loss=require_loss)
            if res:
                break
        if res is None:
            raise SystemExit(f"level {idx + 1}: no valid candidate")
        d, win = res
        d["id"] = idx + 1
        levels.append((d, win))
        prev = win
    return levels


def build_level(index, spec, retry=0):
    _, _, n, colors, _, target = spec
    # A dominant color gives dense boards room to match the easier targets.
    minority = max(colors - 1, round(n * (0.42 - min(target, 0.2)))) if index > 40 else None
    best = None
    for batch in range(3):
        seed = (retry << 40) | (batch << 32) | index
        result = build(seed, *spec, require_loss=True, tries=24, time_limit=None,
                       tolerance=0.005, minority=minority)
        if result is None:
            continue
        error = abs(result[1] - target)
        if minority is None or error <= 0.025:
            return result
        if best is None or error < abs(best[1] - target):
            best = result
    return best


def level_hash(level):
    arrows = sorted(level["arrows"], key=lambda a: (a["x"], a["y"]))
    payload = json.dumps((arrows, level["queue"]), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).digest()


def unique_level(index, spec, result, seen):
    for retry in range(6):
        if retry:
            result = build_level(index, spec, retry)
        if result is not None:
            d, win = result
            digest = level_hash(d)
            if digest not in seen:
                seen.add(digest)
                d["id"] = index
                return d, win
    raise SystemExit(f"level {index}: no unique valid candidate")


def build_levels(specs):
    seen, levels = set(), []
    with multiprocessing.Pool(os.cpu_count()) as pool:
        results = [pool.apply_async(build_level, (index, spec)) for index, spec in enumerate(specs, 1)]
        for index, (spec, result) in enumerate(zip(specs, results), 1):
            levels.append(unique_level(index, spec, result.get(), seen))
            if index % 50 == 0 or index == len(specs):
                print(f"levels: {index}/{len(specs)}", file=sys.stderr, flush=True)
    return levels


def daily(date_str):
    """One deterministic level for a date string like '2026-11-22'."""
    seed = int(hashlib.sha256(date_str.encode()).hexdigest()[:12], 16)
    res = build(seed, 7, 9, 16, 4, 3, 0.30, require_loss=True)
    d, _ = res
    d["id"] = int(date_str.replace("-", ""))
    return d


def write(path, levels):
    for d, _ in levels:
        errors = validate(d)
        if errors:
            raise ValueError(f"level {d['id']}: {errors}")
    with open(path, "w") as f:
        json.dump([d for d, _ in levels], f, separators=(",", ":"))
        f.write("\n")


def write_report(path, levels):
    with open(path, "w", newline="") as f:
        report = csv.writer(f)
        report.writerow(("id", "w", "h", "arrows", "colors", "pocket", "random_win", "difficulty"))
        for d, win in levels:
            n = len(d["arrows"])
            report.writerow((d["id"], d["w"], d["h"], n, len(set(d["queue"])),
                             d["pocket"], f"{win:.3f}", f"{(1 - win) * 100 + n:.1f}"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1, help="seed for the proto set")
    ap.add_argument("--only", choices=("levels", "proto"))
    args = ap.parse_args()
    for name in ("proto", "levels"):
        if args.only is not None and args.only != name:
            continue
        t0 = time.monotonic()
        print(f"{name}: generating", file=sys.stderr, flush=True)
        lv = build_levels(levels_specs()) if name == "levels" else build_set(proto_specs(), args.seed, False, True)
        write(os.path.join(ROOT, "levels", name + ".json"), lv)
        if name == "levels":
            write_report(os.path.join(ROOT, "levels", "levels_report.csv"), lv)
        print(f"levels/{name}.json: {len(lv)} levels in {time.monotonic() - t0:.1f}s", file=sys.stderr)


if __name__ == "__main__":
    main()
