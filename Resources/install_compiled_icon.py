#!/usr/bin/env python3
"""Install a source-checked Xcode-compiled icon catalog into the manual app build."""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import sys

root = Path(__file__).resolve().parent.parent
compiled = root / "Resources/CompiledIcons"
source = root / "Sources/Assets.xcassets/AppIconReference.appiconset"
manifest = json.loads((compiled / "manifest.json").read_text())
assert manifest["iconName"] == "AppIconReference"
actual = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source.iterdir()) if p.is_file()}
assert actual == manifest["sourceFiles"], "Icon sources changed; regenerate Resources/CompiledIcons with Xcode"
car = compiled / "Assets.car"
assert hashlib.sha256(car.read_bytes()).hexdigest() == manifest["assetsSHA256"], "Compiled icon catalog checksum mismatch"
with (compiled / "icon-info.plist").open("rb") as stream:
    partial = plistlib.load(stream)
assert partial.get("CFBundleIconName") == manifest["iconName"], "Unexpected compiled icon asset name"
if len(sys.argv) == 2 and sys.argv[1] == "--validate":
    print("Verified native icon catalog matches its source artwork")
    raise SystemExit(0)
if len(sys.argv) != 2:
    raise SystemExit("Usage: install_compiled_icon.py <app-bundle> | --validate")
app = Path(sys.argv[1]).resolve()
resources = app / "Contents/Resources"
shutil.copyfile(car, resources / "Assets.car")
plist = app / "Contents/Info.plist"
with plist.open("rb") as stream:
    info = plistlib.load(stream)
info["CFBundleIconName"] = manifest["iconName"]
with plist.open("wb") as stream:
    plistlib.dump(info, stream)
print("Installed source-checked native app icon catalog")
