#!/usr/bin/env python3
"""Structural checks for the blog: front matter, series nav, cross-refs, evidence links.

Usage: python3 scripts/check.py   (exit 0 = all green)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POSTS = sorted((ROOT / "blog" / "_posts").glob("*.md"))
failures = []


def fail(msg):
    failures.append(msg)
    print(f"FAIL: {msg}")


for p in POSTS:
    t = p.read_text()
    if not t.startswith("---"):
        fail(f"{p.name}: missing front matter")
        continue
    fm = t.split("---")[1]
    for k in ("title:", "description:", "layout: post", "series: specforge", "date:"):
        if k not in fm:
            fail(f"{p.name}: front matter lacks {k}")
    if "{% include series.html %}" not in t:
        fail(f"{p.name}: missing series nav include")

names = {p.stem for p in POSTS}
for p in POSTS:
    for ref in re.findall(r"post_url ([\d\-a-z]+)", p.read_text()):
        if ref not in names:
            fail(f"{p.name}: post_url {ref} resolves to nothing")

for i, p in enumerate(POSTS, start=1):
    if f"Part {i} of {len(POSTS)}" not in p.read_text():
        fail(f"{p.name}: header is not 'Part {i} of {len(POSTS)}' for its filename order")

nav = (ROOT / "blog" / "_includes" / "series.html").read_text()
if 'sort: "path"' not in nav:
    fail("series.html: nav must sort by path (front-matter dates are backdated,"
         " so date order is not series order)")

for p in POSTS:
    for m in re.findall(r"specforge-blog/(?:tree|blob)/main/([^)]*)", p.read_text()):
        if not (ROOT / m).exists():
            fail(f"{p.name}: evidence link {m} missing")

for f in list((ROOT / "blog").rglob("*.md")) + list((ROOT / "evidence").rglob("*.md")) \
        + list((ROOT / "evidence").rglob("*.json")) + list((ROOT / "evidence").rglob("*.log")):
    if "/Users/" in f.read_text():
        fail(f"{f.relative_to(ROOT)}: absolute path leak")

print(f"{len(POSTS)} posts checked, {len(failures)} failure(s)")
sys.exit(1 if failures else 0)
