#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-build/compiled-icons}"
catalog="build/NotificationIcons.xcassets"
if ! xcrun --find actool >/dev/null 2>&1; then
    echo "Full Xcode with actool is required to regenerate app icon assets." >&2
    exit 1
fi
mkdir -p "$output" "$catalog"
cp Sources/Assets.xcassets/Contents.json "$catalog/Contents.json"
cp -R Sources/Assets.xcassets/AppIconReference.appiconset "$catalog/"
xcrun actool "$catalog" --compile "$output" --platform macosx \
    --minimum-deployment-target 13.0 --app-icon AppIconReference \
    --output-partial-info-plist "$output/icon-info.plist" \
    --output-format human-readable-text --warnings --notices
python3 - "$output" <<'MANIFEST'
from pathlib import Path
import hashlib,json,subprocess,sys
output=Path(sys.argv[1])
source=Path("Sources/Assets.xcassets/AppIconReference.appiconset")
manifest={
    "iconName":"AppIconReference",
    "sourceFiles":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source.iterdir()) if p.is_file()},
    "assetsSHA256":hashlib.sha256((output/"Assets.car").read_bytes()).hexdigest(),
    "xcode":subprocess.check_output(["xcodebuild","-version"],text=True).strip()
}
(output/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
MANIFEST
