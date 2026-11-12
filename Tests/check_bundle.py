#!/usr/bin/env python3
"""Check the actual signed app bundle, rather than Finder custom-icon metadata."""
import plistlib
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys

app = Path(sys.argv[1] if len(sys.argv) > 1 else "TimeTracker.app").resolve()
with (app / "Contents/Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
assert info.get("CFBundleIdentifier") == "com.antigravity.TimeTracker.macOS"
assert info.get("CFBundleVersion") and info.get("CFBundleShortVersionString")
name = info["CFBundleIconFile"]
if not Path(name).suffix:
    name += ".icns"
icon = app / "Contents/Resources" / name
assert icon.is_file(), f"Missing bundled notification icon: {name}"
data = icon.read_bytes()
assert data[:4] == b"icns" and struct.unpack(">I", data[4:8])[0] == len(data)
position, types = 8, set()
while position < len(data):
    kind, size = struct.unpack(">4sI", data[position:position + 8])
    assert size >= 8 and position + size <= len(data)
    types.add(kind)
    position += size
assert position == len(data) and b"ic10" in types, "A valid high-resolution ICNS is required"
assert info.get("CFBundleIconName") == "AppIconReference", "Missing native app icon asset name"
car = app / "Contents/Resources/Assets.car"
assert car.exists(), "An asset-catalog icon name needs its compiled catalog"
manifest = json.loads((Path(__file__).resolve().parent.parent / "Resources/CompiledIcons/manifest.json").read_text())
assert hashlib.sha256(car.read_bytes()).hexdigest() == manifest["assetsSHA256"], "Wrong compiled icon catalog in application bundle"
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
headers = subprocess.check_output(["otool", "-l", str(executable)], text=True)
minimum = re.search(r"\bminos\s+(\d+(?:\.\d+)*)", headers)
assert minimum, "Missing Mach-O deployment target"
actual = tuple(map(int, minimum.group(1).split(".")))
expected = tuple(map(int, info["LSMinimumSystemVersion"].split(".")))
assert actual == expected, f"Binary requires {actual}, but the bundle advertises {expected}"
print("PASS: bundled icon, ICNS structure, strict signature and deployment target")
