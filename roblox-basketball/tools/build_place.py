#!/usr/bin/env python3
"""Build BasketballGame.rbxlx: a Roblox place file with both scripts already in place.

Open the output file in Roblox Studio and press Play; the map builds itself.
Usage: python3 tools/build_place.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "BasketballGame.rbxlx"


def source(name: str) -> str:
    text = (ROOT / name).read_text(encoding="utf-8")
    if "]]>" in text:
        raise SystemExit(f"{name} contains ']]>' which breaks CDATA")
    return text


def script_item(cls: str, ref: str, name: str, src: str) -> str:
    return f"""    <Item class="{cls}" referent="{ref}">
      <Properties>
        <string name="Name">{name}</string>
        <bool name="Disabled">false</bool>
        <ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>
      </Properties>
    </Item>"""


def service(cls: str, ref: str, children: str = "") -> str:
    return f"""  <Item class="{cls}" referent="{ref}">
    <Properties>
      <string name="Name">{cls}</string>
    </Properties>
{children}
  </Item>"""


server = script_item("Script", "RBX_SERVER", "BasketballServer", source("BasketballServer.server.lua"))
client = script_item("LocalScript", "RBX_CLIENT", "BasketballClient", source("BasketballClient.client.lua"))

starter_player_scripts = f"""    <Item class="StarterPlayerScripts" referent="RBX_SPS">
      <Properties>
        <string name="Name">StarterPlayerScripts</string>
      </Properties>
{client.replace(chr(10), chr(10) + "  ")}
    </Item>"""

xml = f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
{service("Workspace", "RBX_WS")}
{service("Lighting", "RBX_LIGHT")}
{service("ReplicatedStorage", "RBX_RS")}
{service("ServerScriptService", "RBX_SSS", server)}
{service("StarterPlayer", "RBX_SP", starter_player_scripts)}
</roblox>
"""

OUT.write_text(xml, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB)")
