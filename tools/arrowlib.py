"""Arrow Traffic: level model, move rules and solver (rules: ../SPEC.md)."""
import random
from collections import Counter

DIRS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
COLORS = ["red", "blue", "green", "yellow", "purple", "orange"]


def arrow_cells(a):
    """Head first, body extends BEHIND the head (opposite of dir)."""
    dx, dy = DIRS[a["dir"]]
    return [(a["x"] - dx * i, a["y"] - dy * i) for i in range(a["len"])]


def arrow_path(a, w, h):
    """Cells in front of the head up to the board edge."""
    dx, dy = DIRS[a["dir"]]
    x, y, out = a["x"] + dx, a["y"] + dy, []
    while 0 <= x < w and 0 <= y < h:
        out.append((x, y))
        x, y = x + dx, y + dy
    return out


def validate(d):
    """Return list of problems (empty == valid)."""
    errs, seen = [], {}
    w, h = d["w"], d["h"]
    for i, a in enumerate(d["arrows"]):
        if a["dir"] not in DIRS or a["len"] < 1 or a["color"] not in COLORS:
            errs.append(f"arrow {i}: bad dir/len/color")
            continue
        for c in arrow_cells(a):
            if not (0 <= c[0] < w and 0 <= c[1] < h):
                errs.append(f"arrow {i}: cell {c} out of board")
            if c in seen:
                errs.append(f"arrow {i}: overlaps arrow {seen[c]} at {c}")
            seen[c] = i
    if Counter(d["queue"]) != Counter(a["color"] for a in d["arrows"]):
        errs.append("queue multiset != arrow colors")
    if d.get("pocket", 0) < 1:
        errs.append("pocket < 1")
    return errs


class SolverLimit(Exception):
    pass


class Level:
    """State = (mask of remaining arrows, queue index, sorted pocket tuple)."""

    def __init__(self, d):
        self.d = d
        self.w, self.h, self.cap = d["w"], d["h"], d["pocket"]
        self.arrows = d["arrows"]
        self.n = len(self.arrows)
        self.color = [a["color"] for a in self.arrows]
        self.queue = list(d["queue"])
        owner = {c: i for i, a in enumerate(self.arrows) for c in arrow_cells(a)}
        self.block = []
        for a in self.arrows:
            m = 0
            for c in arrow_path(a, self.w, self.h):
                if c in owner:
                    m |= 1 << owner[c]
            self.block.append(m)

    def start(self):
        return ((1 << self.n) - 1, 0, ())

    def can_exit(self, mask, i):
        return bool(mask >> i & 1) and not (self.block[i] & mask)

    def moves(self, mask):
        return [i for i in range(self.n) if mask >> i & 1 and not (self.block[i] & mask)]

    def step(self, state, i):
        """Arrow i exits. Returns new state, or None on pocket overflow (LOSS)."""
        mask, qi, pocket = state
        q, c, pocket = self.queue, self.color[i], list(pocket)
        mask &= ~(1 << i)
        if qi < len(q) and q[qi] == c:
            qi += 1
        else:
            if len(pocket) >= self.cap:
                return None
            pocket.append(c)
        while qi < len(q) and q[qi] in pocket:
            pocket.remove(q[qi])
            qi += 1
        return (mask, qi, tuple(sorted(pocket)))

    def _prio(self, i, qi):
        # try arrows the gate wants soonest first
        rest = self.queue[qi:]
        c = self.color[i]
        return rest.index(c) if c in rest else len(rest)

    def solve(self, limit=2_000_000):
        """Memoized DFS. Returns (order or None, explored_states)."""
        dead, order = set(), []

        def rec(s):
            if s[0] == 0:
                return True
            if s in dead:
                return False
            if len(dead) > limit:
                raise SolverLimit
            for i in sorted(self.moves(s[0]), key=lambda i: self._prio(i, s[1])):
                t = self.step(s, i)
                if t is not None and rec(t):
                    order.append(i)
                    return True
            dead.add(s)
            return False

        ok = rec(self.start())
        return (order[::-1] if ok else None), len(dead) + len(order)

    def check_order(self, order):
        s = self.start()
        for i in order:
            if not self.can_exit(s[0], i):
                return False
            s = self.step(s, i)
            if s is None:
                return False
        return s[0] == 0

    def analyze(self, cap=200_000):
        """Exhaustive reachable-state scan. Returns (states, dead_ratio) or (cap, None) if truncated."""
        memo = {}

        def rec(s):
            if s in memo:
                return memo[s]
            if len(memo) >= cap:
                raise SolverLimit
            if s[0] == 0:
                memo[s] = True
                return True
            win = False
            for i in self.moves(s[0]):
                t = self.step(s, i)
                r = rec(t) if t is not None else False  # visit every child, no short-circuit
                win = win or r
            memo[s] = win
            return win

        try:
            rec(self.start())
        except SolverLimit:
            return cap, None
        dead = sum(1 for v in memo.values() if not v)
        return len(memo), dead / len(memo)

    def random_play(self, trials=200, rng=None):
        """Win rate of a player picking uniformly among exitable arrows."""
        rng = rng or random.Random(0)
        wins = 0
        for _ in range(trials):
            s = self.start()
            while s is not None and s[0]:
                mv = self.moves(s[0])
                if not mv:
                    s = None
                    break
                s = self.step(s, rng.choice(mv))
            wins += s is not None
        return wins / trials

    def metrics(self, trials=200, seed=0):
        order, explored = self.solve()
        states, dead_ratio = self.analyze()
        return {
            "solvable": order is not None,
            "solution": order,
            "explored": explored,
            "states": states,
            "dead_ratio": dead_ratio,
            "random_win": self.random_play(trials, random.Random(seed)),
        }
