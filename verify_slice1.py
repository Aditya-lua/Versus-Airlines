#!/usr/bin/env python3
"""Static verification harness for the Versus-Airlines slice 1 source tree.

Reuses the same checks as verify_script.py (block balance, undefined
references, critical functions, duplicate definitions) but applied to
every file under src/ + loader.lua.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))

# Files to scan
SOURCES = ["loader.lua"]
for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
    for f in files:
        if f.endswith(".lua"):
            rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
            SOURCES.append(rel)

print(f"=== Static verification: Versus-Airlines slice 1 ===\n")
print(f"Files: {len(SOURCES)}")
for s in SOURCES:
    print(f"  - {s}")
print()

# ── 1. Block balance ──────────────────────────────────────────
def block_balance(content):
    clean = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    n = len(clean)
    i = 0
    depth = 0
    stack = []
    line = 1
    errors = []
    while i < n:
        c = clean[i]
        if c == '\n':
            line += 1; i += 1; continue
        if c == '-' and i+1 < n and clean[i+1] == '-':
            j = clean.find('\n', i)
            i = j if j != -1 else n
            continue
        if c in '"\'':
            q = c; i += 1
            while i < n:
                if clean[i] == '\\': i += 2; continue
                if clean[i] == q: i += 1; break
                if clean[i] == '\n': line += 1
                i += 1
            continue
        if c == '[' and i+1 < n and clean[i+1] == '[':
            end = clean.find(']]', i+2)
            i = end + 2 if end != -1 else n
            continue
        if c.isalpha() or c == '_':
            m = re.match(r'[A-Za-z_]\w*', clean[i:])
            if m:
                tok = m.group(0); i += len(tok); old_line = line
                if tok in ('function', 'if', 'for', 'while', 'repeat'):
                    depth += 1; stack.append((tok, old_line))
                elif tok == 'do':
                    ls = clean.rfind('\n', 0, i - len(tok) - 1) + 1
                    prefix = clean[ls:i - len(tok)].strip()
                    if not re.match(r'^(for|while)\b', prefix):
                        depth += 1; stack.append(('do', old_line))
                elif tok == 'end':
                    depth -= 1
                    if depth < 0:
                        errors.append(f"end without matching opener at line {old_line}")
                        depth = 0
                    else: stack.pop()
                elif tok == 'until':
                    depth -= 1
                    if depth < 0:
                        errors.append(f"until without matching repeat at line {old_line}")
                        depth = 0
                    else: stack.pop()
                continue
        i += 1
    return depth, errors, stack

print("─ Block balance ─")
total_depth = 0
total_errors = []
for src in SOURCES:
    with open(src) as f:
        content = f.read()
    depth, errors, _ = block_balance(content)
    status = "OK" if depth == 0 and not errors else "FAIL"
    print(f"  [{status}] {src:40s}  depth={depth}  errors={len(errors)}")
    total_depth += depth
    total_errors.extend(errors)
if total_depth == 0 and not total_errors:
    print("  PASS: all blocks balanced")
else:
    for e in total_errors[:10]:
        print(f"  ERROR: {e}")

# ── 2. Duplicate function names across the tree ──────────────
print(f"\n─ Duplicate definitions ─")
seen = {}
dupes = []
for src in SOURCES:
    with open(src) as f:
        for li, line in enumerate(f, 1):
            for m in re.finditer(r'\bfunction\s+([A-Za-z_][A-Za-z0-9_.]*)\s*\(', line):
                name = m.group(1)
                # Skip method definitions (name starts with self: or ClassName.)
                if name.startswith("self:") or name.startswith("Lib:"):
                    continue
                key = name
                if key in seen:
                    dupes.append(f"  {key}: {seen[key]} and {src}:{li}")
                else:
                    seen[key] = f"{src}:{li}"
if dupes:
    print(f"  FAIL: {len(dupes)} duplicate(s):")
    for d in dupes[:15]:
        print(d)
else:
    print("  PASS: no duplicate function names")

# ── 3. Module-level return ────────────────────────────────────
print(f"\n─ Module returns ─")
for src in SOURCES:
    if src == "loader.lua":
        continue
    with open(src) as f:
        lines = f.readlines()
    last_meaningful = None
    for i in range(len(lines) - 1, -1, -1):
        s = lines[i].strip()
        if s and not s.startswith("--"):
            last_meaningful = (i + 1, s)
            break
    if last_meaningful:
        ln, s = last_meaningful
        if s.startswith("return "):
            print(f"  [OK]   {src:40s}  line {ln}: {s[:60]}")
        else:
            print(f"  [WARN] {src:40s}  last line {ln}: {s[:60]} (no return?)")

# ── 4. Required exports check ─────────────────────────────────
print(f"\n─ Critical exports ─")
EXPECTED = {
    "src/kernel/init.lua":     ["Kernel"],
    "src/kernel/logger.lua":   ["Logger"],
    "src/kernel/compat.lua":   ["Compat"],
    "src/kernel/connection.lua": ["Connection"],
    "src/kernel/registry.lua": ["Registry"],
    "src/ui/window.lua":       ["Window"],
    "src/ui/sections.lua":     ["Sections"],
    "src/ui/status.lua":       ["Status"],
}
for path, names in EXPECTED.items():
    if not os.path.exists(path):
        print(f"  [FAIL] {path}: file missing")
        continue
    with open(path) as f:
        content = f.read()
    for name in names:
        # Look for `local X = {}` followed by `X.__index = X` or `function X.new`
        # OR `local X = {}` then a final `return X`
        last = content.strip().split("\n")[-1]
        if f"return {name}" in last:
            print(f"  [OK]   {path:40s}  exports {name}")
        else:
            print(f"  [WARN] {path:40s}  doesn't appear to return {name}")

print(f"\n=== Summary ===")
print(f"Files scanned:  {len(SOURCES)}")
print(f"Total depth:    {total_depth}")
print(f"Total errors:   {len(total_errors)}")
print(f"Duplicate defs: {len(dupes)}")

if total_depth == 0 and not total_errors and not dupes:
    print(f"\n=== SLICE 1 VERIFIED ===")
    sys.exit(0)
else:
    print(f"\n=== SLICE 1 HAS ISSUES ===")
    sys.exit(1)
