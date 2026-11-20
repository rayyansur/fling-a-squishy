"""Collect every Roblox property name the game scripts set on instances they create
(Instance.new(...) then x.Prop = ...), for tools/props.luau to validate against
Roblox's reflection database. Writes out/props.json."""
import re, json, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
uses = {}


def add(cls, prop, where):
    uses.setdefault(cls, {}).setdefault(prop, where)


for f in glob.glob(os.path.join(ROOT, "game/src/**/*.luau"), recursive=True):
    rel = os.path.relpath(f, ROOT)
    src = open(f, encoding="utf-8").read()
    for m in re.finditer(r'local (\w+)\s*(?::\s*\w+)?\s*=\s*Instance\.new\("(\w+)"\)', src):
        var, cls = m.group(1), m.group(2)
        tail = src[m.end(): m.end() + 3000]
        nxt = re.search(r"\n\s*local %s\s*(?::[^=]+)?=" % var, tail)
        if nxt:
            tail = tail[: nxt.start()]
        for k in re.findall(r"\b%s\.([A-Z]\w*)\s*=(?!=)" % var, tail):
            add(cls, k, rel)

os.makedirs(os.path.join(ROOT, "out"), exist_ok=True)
with open(os.path.join(ROOT, "out/props.json"), "w") as fh:
    json.dump(uses, fh)
print(f"collected {sum(len(v) for v in uses.values())} property uses on {len(uses)} classes")
