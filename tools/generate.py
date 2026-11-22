"""Reverse-placement level generator. Usage: python3 tools/generate.py [--seed N]"""
import argparse
import hashlib
import json
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arrowlib import COLORS, DIRS, Level, SolverLimit, arrow_cells, arrow_path, validate  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRIALS = 200
TIME_LIMIT = 20.0  # seconds per level; hit only as a safety net (breaks determinism if it fires)


def place_arrows(rng, w, h, n, lens=(2, 2, 3, 3, 4)):
    """Each new arrow's head path to the edge must be clear of already placed arrows,
    so reversed placement order is a valid exit order. Returns arrows or None."""
    geo = []  # every in-board placement; occupancy only grows, so invalid ones are dropped for good
    for x in range(w):
        for y in range(h):
            for dr in DIRS:
                for ln in sorted(set(lens)):
                    a = {"x": x, "y": y, "dir": dr, "len": ln}
                    cs = arrow_cells(a)
                    if all(0 <= cx < w and 0 <= cy < h for cx, cy in cs):
                        geo.append((a, frozenset(cs), frozenset(arrow_path(a, w, h))))
    occ, arrows, paths = set(), [], []
    for _ in range(n):
        geo = [g for g in geo if occ.isdisjoint(g[1]) and occ.isdisjoint(g[2])]
        if not geo:
            return None
        # prefer arrows that block already placed ones (interlocking), and common lengths
        a, cs, ps = max(geo, key=lambda g: min(sum(1 for p in paths if not p.isdisjoint(g[1])), 2)
                        + lens.count(g[0]["len"]) * 0.5 + rng.random() * 2)
        occ |= cs
        arrows.append(dict(a))
        paths.append(ps)
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


def candidate(rng, w, h, n, ncol, pocket):
    arrows = None
    while arrows is None:
        arrows = place_arrows(rng, w, h, n)
    palette = rng.sample(COLORS, ncol)
    cols = palette + [rng.choice(palette) for _ in range(n - ncol)]
    rng.shuffle(cols)
    for a, c in zip(arrows, cols):
        a["color"] = c
    exit_order = list(range(n))[::-1]
    swaps = rng.randint(0, 4 * n)
    queue = make_queue(rng, [cols[i] for i in exit_order], pocket, swaps)
    return {"id": 0, "w": w, "h": h, "pocket": pocket, "arrows": arrows, "queue": queue}


def build(seed, w, h, n, ncol, pocket, target, max_win=1.0, require_loss=False, tries=60):
    """Generate `tries` candidates, return the solvable one with random win rate closest to target."""
    rng = random.Random(seed)
    best, t0 = None, time.time()
    for k in range(tries):
        if time.time() - t0 > TIME_LIMIT:
            print(f"  warn: time limit hit at candidate {k}", file=sys.stderr)
            break
        d = candidate(rng, w, h, n, ncol, pocket)
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


def levels_specs(count=50):
    out = []
    for i in range(count):
        t = i / (count - 1)
        out.append((round(lerp(5, 8, t)), round(lerp(6, 11, t)), round(lerp(9, 30, t)),
                    round(lerp(2, 5, t)), 4 if t < 0.5 else 3, 0.01 + 0.91 * (1 - t) ** 1.6))
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


def daily(date_str):
    """One deterministic level for a date string like '2026-11-22'."""
    seed = int(hashlib.sha256(date_str.encode()).hexdigest()[:12], 16)
    res = build(seed, 7, 9, 16, 4, 3, 0.30, require_loss=True)
    d, _ = res
    d["id"] = int(date_str.replace("-", ""))
    return d


def summary(d, win):
    n = len(d["arrows"])
    diff = (1 - win) * 100 + n
    return (f"id={d['id']:>2}  {d['w']}x{d['h']:<2}  ok={n:>2}  renk={len(set(d['queue']))}  "
            f"pocket={d['pocket']}  rastgele_kazanma={win * 100:5.1f}%  zorluk={diff:5.1f}")


def write(path, levels):
    for d, _ in levels:
        assert not validate(d), validate(d)
    with open(path, "w") as f:
        json.dump([d for d, _ in levels], f, separators=(",", ":"))
        f.write("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    for name, specs, req, mono in (("proto", proto_specs(), False, True),
                                   ("levels", levels_specs(), True, True)):
        t0 = time.time()
        lv = build_set(specs, args.seed * (1 if name == "proto" else 31), req, mono)
        write(os.path.join(ROOT, "levels", name + ".json"), lv)
        print(f"== levels/{name}.json ({len(lv)} bölüm, {time.time() - t0:.1f}s)")
        for d, win in lv:
            print(summary(d, win))


if __name__ == "__main__":
    main()
