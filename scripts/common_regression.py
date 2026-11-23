#!/usr/bin/env python3
"""Run both native implementations and compare common observable trace fields."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACE = re.compile(r"TRACE\s+(.*)")

def run(target):
    p = subprocess.run(["make", target], cwd=ROOT, text=True, capture_output=True)
    output = p.stdout + p.stderr
    if p.returncode:
        print(output)
        raise SystemExit(f"{target} failed with {p.returncode}")
    rows = TRACE.findall(output)
    if not rows:
        raise SystemExit(f"{target} produced no TRACE record")
    fields = dict(item.split("=", 1) for item in rows[-1].split())
    return fields

def run_stress(target):
    p = subprocess.run(["make", target], cwd=ROOT, text=True, capture_output=True)
    output = p.stdout + p.stderr
    if p.returncode:
        print(output)
        raise SystemExit(f"{target} failed with {p.returncode}")
    rows = re.findall(r"(?:AXI RANDOM PASS|BSV AXI RANDOM PASS)\s+seed=\S+\s+transactions=(\d+)", output)
    if not rows:
        raise SystemExit(f"{target} produced no stress PASS record")
    return {"transactions": rows[-1]}

def compare(target, keys):
    sv = run("sv-" + target)
    bsv = run("bsv-" + target)
    bad = [(k, sv.get(k), bsv.get(k)) for k in keys if sv.get(k) != bsv.get(k)]
    if bad:
        for item in bad:
            print("TRACE MISMATCH", target, item)
        raise SystemExit(1)
    print("COMMON TRACE PASS", target, " ".join(f"{k}={sv[k]}" for k in keys))

compare("test", ("scenario", "ownership", "c_unauthorized", "e_result"))
compare("feed", ("scenario", "mode", "c_input", "c_start", "c_policy", "e_result"))

sv_stress = run_stress("sv-axi-random")
bsv_stress = run_stress("bsv-axi-random")
if sv_stress.get("transactions") != bsv_stress.get("transactions"):
    raise SystemExit(f"STRESS COUNT MISMATCH {sv_stress} {bsv_stress}")
print("COMMON STRESS PASS transactions=" + sv_stress["transactions"])
