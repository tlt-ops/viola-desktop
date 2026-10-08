#!/usr/bin/env python3
"""Protect the saved original rocking/kicking laugh during unrelated edits."""
import hashlib, json, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
contract = json.loads((root / "docs/original-laugh-v4-contract.json").read_text())
failures = []
for rel, expected in contract["sha256"].items():
    path = root / rel
    actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else "missing"
    if actual != expected: failures.append(rel)
for rel, required in contract["required"].items():
    text = (root / rel).read_text()
    failures += [rel+": missing "+token for token in required if token not in text]
for rel, forbidden in contract["forbidden"].items():
    text = (root / rel).read_text()
    failures += [rel+": obsolete "+token for token in forbidden if token in text]
if failures:
    print("Saved original rocking laugh changed: " + ", ".join(failures))
    print("Keep the saved clip during keyboard/mouse/crawl edits. Revise only after an explicit user request to change the laugh.")
    sys.exit(1)
print("PASS original rocking laugh v4 motion, pose, face constants and integration contract")
