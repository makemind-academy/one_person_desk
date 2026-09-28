#!/usr/bin/env python3
"""one-person-desk: every item carries its source, the ordering rule is printed, and one hat narrows the list."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
from appplayer import AppPlayer  # noqa: E402
from mcpclient import Server  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.join(HERE, "desk_server")
CAP = os.path.join(HERE, "captures")
SERVER_ID = "com.makemind.sample.desk"

with Server(["dart", "run", "bin/server.dart"], cwd=SERVER) as s:
    desk = s.call("desk.all")
    assert desk["rowCount"] == 6
    assert all(r["source"] for r in desk["rows"]), "every item names where it came from"
    late = [r for r in desk["rows"] if r.get("late")]
    assert desk["rows"][: len(late)] == late, "late items come first, as the rule on screen says"
    sales = s.call("desk.hat", {"hat": "sales"})
    assert sales["rowCount"] < desk["rowCount"] and sales["rule"] == desk["rule"]

ap = AppPlayer()
ap.register_server(SERVER_ID, "One-person desk", cwd=SERVER)
ap.restart()
ap.open_server(SERVER_ID)
ap.wait_text("items across")
ap.expect_text("6 items across 4 hats")
ap.expect_aligned("$", min_rows=3)
ap.shot(f"{CAP}/01_desk.png")
ap.tap("sales")
ap.wait_text("2 items")
ap.shot(f"{CAP}/02_one_hat.png")
print("one-person-desk: sourced items in rule order, one hat on screen")
