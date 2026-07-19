#!/usr/bin/env python3
"""
    Versus-Airlines :: scripts/mine_data
    -------------------------------------
    Mine the 17 data files from UltimateBloxFruits_Fluent.lua into
    src/game/data/*.lua.

    This is a one-shot script. Re-run it whenever the upstream dump
    changes and you want to refresh the data files. The data files
    themselves are committed; the miner is the regenerator.

    Mining protocol (per docs/STYLE.md + memory D20):
        - Read UltimateBloxFruits_Fluent.lua.
        - Extract the 17 data tables by name.
        - Emit each as a standalone .lua file under src/game/data/.
        - Each file starts with the Mined header comment.
        - Each file ends with a "return {...}" line.
        - No data is altered — this is a copy, not a transformation.

    Tables extracted:
        Sea1Quests, Sea2Quests, Sea3Quests,
        BossData, SwordData, FightingStyleData,
        FruitData, AccessoryData, GunData,
        MaterialFarmData, RaidData, RaceV4Data,
        SeaEventNames, IslandCFrames, QuestNPCData,
        FruitBuyingData, EnemySpawnDB
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DUMP = os.path.join(ROOT, "UltimateBloxFruits_Fluent.lua")
OUT_DIR = os.path.join(ROOT, "src/game/data")
HEADER = """--[[
    Versus-Airlines :: src/game/data/{name}
    -----------------------------------------
    --- Mined from UltimateBloxFruits_Fluent.lua on 2026-07-16.
    --- Do not edit; regenerate from upstream via scripts/mine_data.py. ---

    Format: a single Lua table returned at the bottom of the file.
    Modules load it with `local data = require("src.game.data.{name}")`
    (or via the kernel's data registry, slice 4).
]]

"""


# ---- table extraction ----
# Each entry: (lua-name-in-dump, output-filename, parser-function)
# The parser takes the raw `local NAME = { ... }` body string (without
# the surrounding `local NAME = ` and `}`) and returns a clean
# multi-line string of the table contents to be inserted between
# `{` and `}` in the output file.

def find_table_body(text, name):
    """Find the body of `local <name> = { ... }` in text.

    Returns the contents strictly between the outer { and the matching
    }, or None if not found.
    """
    # Match `local NAME = {` with NAME possibly followed by whitespace.
    pat = re.compile(r'local\s+' + re.escape(name) + r'\s*=\s*\{')
    m = pat.search(text)
    if not m:
        return None
    # Walk forward, counting braces.
    i = m.end() - 1   # index of the opening `{`
    depth = 0
    in_string = False
    string_quote = None
    j = i
    while j < len(text):
        c = text[j]
        if in_string:
            if c == '\\':
                j += 2
                continue
            if c == string_quote:
                in_string = False
        else:
            if c in '"\'':
                in_string = True
                string_quote = c
            elif c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    return text[i+1:j]
        j += 1
    return None


def reindent(body, prefix="    "):
    """Re-indent body lines with the given prefix."""
    out = []
    for line in body.split('\n'):
        if line.strip() == '':
            out.append('')
        else:
            out.append(prefix + line)
    return '\n'.join(out)


# ---- emit a file ----
def emit(name, body):
    if body is None:
        print(f"  [SKIP] {name}: table not found in dump")
        return False
    out_path = os.path.join(OUT_DIR, name + ".lua")
    content = HEADER.format(name=name) + "return {\n" + reindent(body, "    ") + "\n}\n"
    with open(out_path, 'w') as f:
        f.write(content)
    size = os.path.getsize(out_path)
    print(f"  [OK]   {name:30s}  {size:>7} bytes")
    return True


# ---- main ----
def main():
    if not os.path.exists(SRC_DUMP):
        print(f"ERROR: source dump not found at {SRC_DUMP}")
        sys.exit(1)

    os.makedirs(OUT_DIR, exist_ok=True)

    with open(SRC_DUMP) as f:
        text = f.read()

    print(f"Mining {SRC_DUMP} -> {OUT_DIR}\n")

    tables = [
        # (lua-name-in-dump, output-filename)
        ("Sea1Quests",         "sea1_quests"),
        ("Sea2Quests",         "sea2_quests"),
        ("Sea3Quests",         "sea3_quests"),
        ("BossData",           "bosses"),
        ("SwordData",          "swords"),
        ("FightingStyleData",  "fighting_styles"),
        ("FruitData",          "fruits"),
        ("AccessoryData",      "accessories"),
        ("GunData",            "guns"),
        ("MaterialFarmData",   "materials"),
        ("RaidData",           "raids"),
        ("RaceV4Data",         "race_v4"),
        ("SeaEventNames",      "sea_events"),
        ("IslandCFrames",      "islands"),
        ("QuestNPCData",       "quest_npcs"),
        ("FruitBuyingData",    "fruit_dealers"),
        ("EnemySpawnDB",       "enemy_spawn_db"),
    ]

    ok = fail = 0
    for lua_name, out_name in tables:
        body = find_table_body(text, lua_name)
        if emit(out_name, body):
            ok += 1
        else:
            fail += 1

    print(f"\n{ok} extracted, {fail} skipped.")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
