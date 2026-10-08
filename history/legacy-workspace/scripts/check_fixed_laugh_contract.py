#!/usr/bin/env python3
"""Fail if the saved belly-laugh clip or its pinned art was changed."""
import hashlib, json, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
contract = json.loads((root / "docs/layered-rocking-v5-contract.json").read_text())
failures = []
for rel, expected in contract["sha256"].items():
    path = root / rel
    actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else "missing"
    if actual != expected:
        failures.append(rel)
for rel, required in contract.get("required", {}).items():
    source = (root / rel).read_text()
    failures += [rel+": missing "+token for token in required if token not in source]
if failures:
    print("Layered rocking belly-laugh v5 changed: " + ", ".join(failures))
    print("Keep the saved clip when changing keyboard/mouse/crawl. Revise this contract only after an explicit user request to change the laugh.")
    sys.exit(1)
print("PASS layered rocking belly-laugh v5 source and pinned-art contract")
