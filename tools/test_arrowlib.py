import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arrowlib import Level, arrow_cells, validate  # noqa: E402
import generate  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def A(x, y, d, ln, c):
    return {"x": x, "y": y, "dir": d, "len": ln, "color": c}


def lvl(arrows, queue, pocket=3, w=5, h=5):
    return {"id": 1, "w": w, "h": h, "pocket": pocket, "arrows": arrows, "queue": queue}


class Rules(unittest.TestCase):
    def test_body_behind_head(self):
        self.assertEqual(arrow_cells(A(2, 1, "up", 3, "red")), [(2, 1), (2, 2), (2, 3)])
        self.assertEqual(arrow_cells(A(2, 1, "left", 2, "red")), [(2, 1), (3, 1)])

    def test_blocked_and_free(self):
        # a points right at row 0, b sits in its path
        lv = Level(lvl([A(0, 0, "right", 1, "red"), A(3, 0, "up", 2, "blue")], ["red", "blue"]))
        m = (1 << 2) - 1
        self.assertFalse(lv.can_exit(m, 0))
        self.assertTrue(lv.can_exit(m, 1))
        self.assertTrue(lv.can_exit(0b01, 0))
        # an arrow pointing away from a neighbour is never blocked by it
        lv2 = Level(lvl([A(1, 0, "up", 2, "red"), A(1, 2, "down", 2, "red")], ["red", "red"]))
        self.assertEqual(lv2.moves(0b11), [0, 1])

    def test_pocket_overflow_loses(self):
        # queue wants red first, but only blues can leave first
        arrows = [A(x, 0, "up", 1, "blue") for x in range(3)] + [A(0, 1, "up", 1, "red")]
        lv = Level(lvl(arrows, ["red", "blue", "blue", "blue"], pocket=2))
        s = lv.start()
        s = lv.step(s, 0)
        s = lv.step(s, 1)
        self.assertEqual(s[2], ("blue", "blue"))
        self.assertIsNone(lv.step(s, 2))  # pocket full -> LOSS

    def test_chain_release_from_pocket(self):
        arrows = [A(0, 0, "up", 1, "blue"), A(1, 0, "up", 1, "green"), A(2, 0, "up", 1, "red")]
        lv = Level(lvl(arrows, ["red", "blue", "green"], pocket=2))
        s = lv.step(lv.step(lv.start(), 0), 1)
        self.assertEqual(s, (0b100, 0, ("blue", "green")))
        s = lv.step(s, 2)  # red passes, then blue and green cascade out of pocket
        self.assertEqual(s, (0, 3, ()))

    def test_solver(self):
        arrows = [A(x, 0, "up", 1, "blue") for x in range(3)] + [A(0, 1, "up", 1, "red")]
        lv = Level(lvl(arrows, ["red", "blue", "blue", "blue"], pocket=2))
        order, _ = lv.solve()
        self.assertTrue(lv.check_order(order))
        states, dead = lv.analyze()
        self.assertGreater(states, 1)
        self.assertGreater(dead, 0)
        self.assertLess(lv.random_play(), 1.0)
        # red under two blues in one column, gate wants red first, pocket 1 -> impossible
        col = [A(0, 0, "up", 1, "blue"), A(0, 1, "up", 1, "blue"), A(0, 2, "up", 1, "red")]
        unsolvable = Level(lvl(col, ["red", "blue", "blue"], pocket=1))
        self.assertIsNone(unsolvable.solve()[0])


class Generated(unittest.TestCase):
    def check_file(self, name, count):
        with open(os.path.join(ROOT, "levels", name)) as f:
            levels = json.load(f)
        self.assertEqual(len(levels), count)
        self.assertEqual([d["id"] for d in levels], list(range(1, count + 1)))
        for d in levels:
            with self.subTest(file=name, id=d["id"]):
                self.assertEqual(validate(d), [])
                lv = Level(d)
                order, _ = lv.solve()
                self.assertIsNotNone(order)
                self.assertTrue(lv.check_order(order))
        return levels

    def test_proto(self):
        self.check_file("proto.json", 10)

    def test_levels(self):
        levels = self.check_file("levels.json", 50)
        for d in levels:
            self.assertLess(Level(d).random_play(), 1.0, f"level {d['id']} never loses")

    def test_daily_deterministic(self):
        a, b = generate.daily("2026-11-22"), generate.daily("2026-11-22")
        self.assertEqual(a, b)
        self.assertEqual(validate(a), [])
        self.assertIsNotNone(Level(a).solve()[0])
        self.assertNotEqual(a, generate.daily("2026-11-23"))


if __name__ == "__main__":
    unittest.main()
