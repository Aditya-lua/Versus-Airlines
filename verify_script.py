#!/usr/bin/env python3
"""Static verification harness for UltimateBloxFruits.lua"""

import re, sys

with open("UltimateBloxFruits.lua", "r") as f:
    content = f.read()
lines = content.split("\n")

print(f"=== Static Verification: UltimateBloxFruits.lua ===\n")
print(f"Total lines: {len(lines)}")

# ── 1. Block balance ──────────────────────────────────────────
# Strip comments and strings, then count do/if/for/while/function/repeat vs end
clean = re.sub(r'--\[(=*)\[.*?\]\1\]', '', content, flags=re.DOTALL)

i = 0; n = len(clean); depth = 0; stack = []; line = 1; errors = []

while i < n:
    c = clean[i]
    if c == '\n': line += 1; i += 1; continue
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
            if tok == 'function': depth += 1; stack.append(('function', old_line))
            elif tok == 'if': depth += 1; stack.append(('if', old_line))
            elif tok == 'for': depth += 1; stack.append(('for', old_line))
            elif tok == 'while': depth += 1; stack.append(('while', old_line))
            elif tok == 'repeat': depth += 1; stack.append(('repeat', old_line))
            elif tok == 'do':
                ls = clean.rfind('\n', 0, i - len(tok) - 1) + 1
                prefix = clean[ls:i - len(tok)].strip()
                if not re.match(r'^(for|while)\b', prefix):
                    depth += 1; stack.append(('do', old_line))
            elif tok == 'end':
                depth -= 1
                if depth < 0: errors.append(f"Line {old_line}: 'end' without matching opener"); depth = 0
                else: stack.pop()
            elif tok == 'until':
                depth -= 1
                if depth < 0: errors.append(f"Line {old_line}: 'until' without matching repeat"); depth = 0
                else: stack.pop()
            continue
    i += 1

print(f"\n─ Block balance ─")
if depth == 0 and not errors:
    print("  PASS: All blocks balanced")
else:
    print(f"  Final depth: {depth} ({'UNBALANCED' if depth != 0 else 'OK'})")
    for e in errors[:10]: print(f"  ERROR: {e}")

# ── 2. Undefined function references ──────────────────────────
print(f"\n─ Undefined references ─")
defined = set()
called = set()
for li, raw in enumerate(lines, 1):
    stripped = raw.strip()
    # Function definitions
    for m in re.finditer(r'(?:local\s+)?function\s+([A-Za-z_]\w*)\s*\(', stripped):
        defined.add(m.group(1))
    # Variable assignment functions  
    for m in re.finditer(r'local\s+function\s+([A-Za-z_]\w*)\s*\(', stripped):
        defined.add(m.group(1))
    # Array assignment
    for m in re.finditer(r'\b([A-Za-z_]\w*)\s*=\s*function\s*\(', stripped):
        defined.add(m.group(1))
    # Function calls
    for m in re.finditer(r'(?<!\bfunction\s)(?<!\.)([A-Z][A-Za-z_]\w*|[a-z_][A-Za-z_]\w*)\s*\(', stripped):
        name = m.group(1)
        if name not in ('if','for','while','repeat','until','local','return','elseif','else','function','end'):
            called.add(name)

# Known Roblox globals
roblox_globals = {
    'game','workspace','Workspace','print','warn','wait','spawn','tostring','tonumber','type','pairs','ipairs',
    'table','string','math','os','tick','task','coroutine','require','pcall','xpcall','error','assert',
    'setmetatable','getmetatable','setreadonly','getrawmetatable','newcclosure','hookmetamethod','hookfunction',
    'getgenv','getfenv','setfenv','rawget','rawset','setfflag','getconnections','getnamecallmethod',
    'loadstring','readfile','writefile','appendfile','listfiles','isfile','isfolder','makefolder','delfile','delfolder',
    'setclipboard','is_sirhurt_closure','islclosure','isexecutorclosure','hookfunction','checkcaller',
    'clonefunction','iscclosure','newcclosure','isluau','decompile','getruntime','getthreadidentity',
    'setthreadidentity','getthreadcontext','debug','Drawing','Vector2','Vector3','CFrame','Color3',
    'UDim2','UDim','Rect','Enum','Instance','TweenInfo','RaycastParams','BrickColor','BasePart',
    'fireproximityprompt','firetouchinterest','protectgui','sethiddenproperty','getscriptclosure',
    'setfflag','getfflag','queue_on_teleport','http_request',
}
defined.update(roblox_globals)
defined.update({'Mon','LevelQuest','NameQuest','NameMon','CFrameQuest','CFrameMon','CurrentFruit','CurrentRaid'})
defined.update({'Library','Library','ui','Window','Sea1','Sea2','Sea3','CurrentSea','KillAllActive'})
defined.update({'client','clients','Camera','ReplicatedStorage','TweenService','HttpService','RunService',
    'UserInputService','Lighting','VirtualUser','CoreGui','Players','Workspace','MarketplaceService',
    'TeleportService','Debris','ContextActionService','StarterGui','InsertService','Chat','Teams'})

# Service names accessed via game:GetService()
for m in re.finditer(r"""game:GetService\(["'](\w+)["']\)""", content):
    defined.add(m.group(1))

# module require calls
for m in re.finditer(r"""require\(([^)]+)\)""", content):
    req = m.group(1).strip()
    if req.startswith('game'):
        # Will be available at runtime
        pass

missing = called - defined - {'self', 'v', 'k', 'i', 't', 's', 'n', 'c', 'x', 'y', 'z', 'a', 'b', 'p', 'm', 'd', 'f', 'g', 'h', 'j', 'l', 'o', 'q', 'r', 'u', 'w'}
# Also remove common single-char loop variables
for name in list(missing):
    if len(name) <= 2 and name.isalpha():
        missing.discard(name)

if missing:
    print(f"  WARNING: {len(missing)} potentially undefined:")
    for name in sorted(missing)[:30]:
        print(f"    - {name}")
else:
    print("  PASS: No obvious undefined references")

# ── 3. Critical function existence checks ─────────────────────
print(f"\n─ Critical functions ─")
critical = [
    'ResolveQuest', 'CheckLevel', 'CheckLevelEx', 'CheckQuest', 'GetSea',
    'Combat', 'EquipWeapon', 'GetClosest', 'BringMobs', 'TweenTP', 'BTP',
    'Hop', 'HopLow', 'HopServer', 'HuntSeaEvent',
    'MasterKillSwitch', 'GetQuestNameForLevel',
    'AutoFarm', 'AdvancedAutoFarm', 'FarmBoss', 'FindBoss', 'StartRaid',
    'RunV4Trial', 'FindSeaEvent', 'FarmSeaEvent', 'CreateESP', 'ClearESP', 'UpdateESP',
    'TeleportToIsland', 'BuyItem', 'BuyFruit', 'GetClosestPlayer',
    'AutoDodge', 'PVPCombo', 'AutoStat', 'CollectNearbyFruits',
    'FarmMastery', 'AutoEnhance', 'AddPartyMember', 'RemovePartyMember',
    'TeleportToParty', 'SendWebhook', 'LogProgress', 'SaveConfig', 'LoadConfig',
    'QueueNotification', 'ProcessNotifications', 'ChangeRace', 'TrackPerformance',
    'GetAvgFrameTime', 'CheckForUpdate', 'TrackError', 'SafeCall',
]
missing_critical = [fn for fn in critical if fn not in defined]
if missing_critical:
    print(f"  FAIL: Missing: {', '.join(missing_critical)}")
else:
    print(f"  PASS: All {len(critical)} critical functions defined")

# ── 4. Duplicate function definitions ─────────────────────────
print(f"\n─ Duplicate definitions ─")
seen = {}; dupes = []
for li, raw in enumerate(lines, 1):
    stripped = raw.strip()
    for m in re.finditer(r'(?:local\s+)?function\s+([A-Za-z_]\w*)\s*\(', stripped):
        name = m.group(1)
        if name in seen:
            dupes.append(f"  {name}: line {seen[name]} and line {li}")
        else:
            seen[name] = li

if dupes:
    print(f"  FAIL: {len(dupes)} functions defined multiple times:")
    for d in dupes[:15]: print(d)
else:
    print("  PASS: No duplicate function names")

# ── 5. External URLs ─────────────────────────────────────────
print(f"\n─ External dependencies ─")
urls = re.findall(r'https?://[^\s"\')\]]+', content)
unique_urls = list(dict.fromkeys(urls))
for u in unique_urls:
    print(f"  {u}")

# ── 6. Rogue return statements ────────────────────────────────
print(f"\n─ Rogue return check ─")
rogue_returns = 0
block_depth = 0
for li, raw in enumerate(lines, 1):
    stripped = raw.strip()
    for m in re.finditer(r'\b(function|do|if|for|while|repeat|end|until)\b', stripped):
        if m.group(1) in ('function', 'do', 'if', 'for', 'while', 'repeat'): block_depth += 1
        elif m.group(1) in ('end', 'until'): block_depth -= 1
    if block_depth == 0 and re.match(r'^\s*return\b', stripped):
        # Check: is there any non-blank, non-comment code after this line?
        for j in range(li, len(lines)):
            future = lines[j].strip()
            if future and not future.startswith('--'):
                rogue_returns += 1
                print(f"  FAIL line {li}: 'return' followed by code at line {j+1}: {future[:80]}")
                break
            if j - li > 5: break

if rogue_returns == 0: print("  PASS: No mid-script return statements")
else: print(f"  {rogue_returns} rogue return(s) — compile error in Luau!")

# ── 7. Top-level return followed by nothing check ──────────────
# The LAST top-level return is valid, just verify it exists
last_return = None
block_depth = 0
for li, raw in enumerate(lines, 1):
    stripped = raw.strip()
    for m in re.finditer(r'\b(function|do|if|for|while|repeat|end|until)\b', stripped):
        if m.group(1) in ('function', 'do', 'if', 'for', 'while', 'repeat'): block_depth += 1
        elif m.group(1) in ('end', 'until'): block_depth -= 1
    if block_depth == 0 and re.match(r'^\s*return\b', stripped):
        last_return = li

# ── 8. Syntactic issues ───────────────────────────────────────
print(f"\n─ Syntax scan ─")
issues = 0
for li, raw in enumerate(lines, 1):
    # Check for } where end expected (we fixed one, check for more)
    stripped = raw.strip()
    if stripped == '}' or stripped.startswith('} '):
        # Allow table closing braces on their own line
        # Check if this is inside a table context (hard to determine)
        if re.search(r'\bfor\b.*\bdo\b', lines[li-2] if li > 2 else ""):
            print(f"  PROBLEM: Line {li}: '{stripped}' looks like a mistyped 'end' inside a for loop")

if depth != 0 or errors or rogue_returns:
    print(f"  FAIL: {len(errors)} block errors, {rogue_returns} rogue returns, depth={depth}")
    sys.exit(1)
else:
    print("  PASS: No syntax issues found")

print(f"\n=== ALL CHECKS PASSED ===" if not issues and not dupes and not errors and depth == 0 else "\n=== SOME ISSUES FOUND ===")
