#!/usr/bin/env python3
"""Style standard verifier for the Versus-Airlines source tree.

Enforces the rules in docs/STYLE.md. Exits 0 on clean, 1 on any violation.
Each check is independent and reports its own line numbers so the author
can fix them in one pass.

Usage:  python3 docs/verify.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Files to scan
SOURCES = []
for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
    for f in files:
        if f.endswith(".lua"):
            rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
            SOURCES.append(rel)
if os.path.exists(os.path.join(ROOT, "loader.lua")):
    SOURCES.insert(0, "loader.lua")

def read(p):
    with open(p) as f:
        return f.read()

def lines(p):
    with open(p) as f:
        return f.readlines()

violations = []

def v(file, line_no, rule, msg):
    violations.append(f"  {file}:{line_no}  [{rule}]  {msg}")


# ── Rule 1: file header ───────────────────────────────────────
HEADER_RE = re.compile(
    r'^--\[\[\s*\n'
    r'\s*Versus-Airlines :: [^\n]+\n'
    r'\s*-{3,}\n'
    r'(?:\s*[^\n]+\n)+?'
    r'\s*(?:Public API:|\]\])',
    re.MULTILINE
)

for src in SOURCES:
    content = read(os.path.join(ROOT, src))
    if not HEADER_RE.search(content):
        v(src, 1, "R1", "missing or malformed file header")


# ── Rule 3: indentation (4 spaces, no tabs) ───────────────────
TAB_RE = re.compile(r'^\t', re.MULTILINE)
for src in SOURCES:
    for i, line in enumerate(lines(os.path.join(ROOT, src)), 1):
        if TAB_RE.match(line):
            v(src, i, "R3", "tab character (use 4 spaces)")
        if line.rstrip('\n').rstrip() != line.rstrip('\n'):
            v(src, i, "R3", "trailing whitespace")

# ── Rule 4: section dividers must use -- prefix ────────────────
# Pattern: a line containing ============== without a -- prefix.
DANGEROUS_DIV = re.compile(r'^\s*={3,}\s*$', re.MULTILINE)
for src in SOURCES:
    for i, line in enumerate(lines(os.path.join(ROOT, src)), 1):
        if DANGEROUS_DIV.match(line):
            v(src, i, "R4", "section divider missing -- prefix")


# ── Rule 5: magic floats (heuristic) ───────────────────────────
# Flag any float literal in a function body (not the constants block)
# that has more than 1 decimal place AND is not a known constant name.
KNOWN_CONST = re.compile(
    r'^\s*local\s+([A-Z][A-Z0-9_]+)\s*=\s*([\d.]+)',
    re.MULTILINE
)
FLOAT_RE = re.compile(r'\b\d+\.\d{2,}\b')

for src in SOURCES:
    content = read(os.path.join(ROOT, src))
    # collect known constant names from this file
    constants = set()
    for m in KNOWN_CONST.finditer(content):
        constants.add(m.group(1))
    # walk the file line-by-line, ignoring the constants block (top 40 lines)
    for i, line in enumerate(lines(os.path.join(ROOT, src)), 1):
        if i <= 40:
            continue  # the constants block lives at the top
        for m in FLOAT_RE.finditer(line):
            # check if the float is in a comment
            before = line[:m.start()]
            if '--' in before and before.rfind('--') > before.rfind('\n'):
                continue
            v(src, i, "R5", f"magic float {m.group(0)} (should be a named constant)")


# ── Rule 6: no "discord.gg/" attribution lines ────────────────
DISCORD_RE = re.compile(r'(?i)\bdiscord\.gg/\S+')
for src in SOURCES:
    for i, line in enumerate(lines(os.path.join(ROOT, src)), 1):
        if DISCORD_RE.search(line):
            v(src, i, "R6", "discord.gg/... attribution (move to commit message)")


# ── Rule 9: no :Connect( outside the kernel dir ───────────────
CONNECT_RE = re.compile(r':Connect\s*\(')
for src in SOURCES:
    if src.startswith("src/kernel/") or src == "loader.lua":
        continue
    for i, line in enumerate(lines(os.path.join(ROOT, src)), 1):
        if CONNECT_RE.search(line):
            v(src, i, "R9", "raw :Connect( call (use kernel.conn:track instead)")


# ── Rule 11: no duplicate flagName in sections.lua ───────────
SECTIONS = os.path.join(ROOT, "src/ui/sections.lua")
if os.path.exists(SECTIONS):
    seen_flags = {}
    for i, line in enumerate(lines(SECTIONS), 1):
        for m in re.finditer(r'flagName\s*=\s*"([^"]+)"', line):
            name = m.group(1)
            if name in seen_flags:
                v(SECTIONS, i, "R11", f"duplicate flagName '{name}' (first seen at line {seen_flags[name]})")
            else:
                seen_flags[name] = i


# ── Rule 12: no commented-out code blocks ────────────────────
# Heuristic: a -- line that LOOKS LIKE a full statement. We require
# at least TWO Luau-keyword-shaped tokens (a control structure AND an
# assignment or call) to avoid false positives on prose like
# "-- if a non-connection is passed." which legitimately contain
# words like "if".
SUSPECT_CODE = re.compile(
    r'--\s*.*\b(function|local)\b.*\b(return|then|do|end|if|for|while)\b',
    re.MULTILINE
)
# Also flag: --local X = ... (a one-line comment that is itself a local
LOCAL_IN_COMMENT = re.compile(r'--\s*local\s+[A-Za-z_]\w*\s*=', re.MULTILINE)
for src in SOURCES:
    for i, line in enumerate(lines(os.path.join(ROOT, src)), 1):
        if SUSPECT_CODE.search(line) or LOCAL_IN_COMMENT.search(line):
            v(src, i, "R12", "looks like commented-out code")


# ── Output ─────────────────────────────────────────────────────
print("=== Versus-Airlines :: STYLE.md verification ===\n")
print(f"Files scanned: {len(SOURCES)}")
for s in SOURCES:
    print(f"  - {s}")
print()

if not violations:
    print("PASS: 0 violations")
    sys.exit(0)
else:
    print(f"FAIL: {len(violations)} violation(s)")
    for x in violations:
        print(x)
    sys.exit(1)
