#!/usr/bin/env python3
"""Bundles the project + the mock engine + a scenario into one Luau file that the
stand-alone `luau` CLI can execute:  python3 tests/bundle.py tests/scenario_server.luau > /tmp/run.luau"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPPING = [
    ("ReplicatedStorage/Shared", "src/shared"),
    ("ServerScriptService/Server", "src/server"),
    ("StarterPlayer/StarterPlayerScripts/Client", "src/client"),
]

def module_entries():
    out = []
    for dm_path, rel in MAPPING:
        base = os.path.join(ROOT, rel)
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                if not f.endswith(".luau"):
                    continue
                full = os.path.join(dirpath, f)
                sub = os.path.relpath(full, base)
                name = f[:-5]
                cls = "ModuleScript"
                if name.endswith(".server"):
                    name, cls = name[:-7], "Script"
                elif name.endswith(".client"):
                    name, cls = name[:-7], "LocalScript"
                parts = os.path.dirname(sub).split(os.sep) if os.path.dirname(sub) else []
                key = "/".join([dm_path] + parts + [name])
                out.append((key, cls, full))
    return out

def main():
    scenario = sys.argv[1]
    lines = []
    lines.append("local M = (function()\n" + open(os.path.join(ROOT, "tests/mock/roblox.luau")).read() + "\nend)()")
    lines.append("local SOURCES, CLASSES = {}, {}")
    for key, cls, full in module_entries():
        src = open(full).read()
        lines.append(f'CLASSES["{key}"] = "{cls}"')
        lines.append(f'SOURCES["{key}"] = function(script)\n{src}\nend')
    lines.append(open(os.path.join(ROOT, "tests/mock/loader.luau")).read())
    lines.append(open(os.path.join(ROOT, scenario)).read())
    sys.stdout.write("\n".join(lines))

main()
