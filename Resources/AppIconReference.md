# App and notification icon resources

`AppIconReference.icns` and `AppIconReference.png` were extracted without redrawing
from the installed reference app selected by the user. The matching
`Sources/Assets.xcassets/AppIconReference.appiconset` is the editable source.

## Native compiled catalog

`Resources/CompiledIcons/Assets.car` is compiled from that asset set using Xcode.
The manifest records source checksums, the catalog checksum, the Xcode version,
and the one-time GitHub Actions build used to generate it. The temporary build
branch was removed after the artifact was downloaded and verified.

The manual build validates the catalog against the source artwork, copies it into
`Contents/Resources`, and sets `CFBundleIconName` before signing. The ICNS file is
retained as the fallback declared by `CFBundleIconFile`. XcodeGen uses the same
asset name and compiles the source asset catalog directly.

To regenerate the catalog on a Mac with full Xcode selected:

```sh
bash Resources/compile_app_icon.sh Resources/CompiledIcons
```

After a normal build, verify the actual bundle:

```sh
python3 Tests/check_bundle.py TimeTracker.app
```

## Verify a real system notification

Open Settings > Test system notification, or launch the app with
`--notification-icon-test`. The quiet test notification includes its app version
and build number so it can be distinguished from earlier notifications. A Finder
icon preview does not verify Notification Center rendering. Notification setup
runs after AppKit finishes launching and refreshes the app registration first.

## Optional local Finder appearance

`MATCH_REFERENCE_FINDER_ICON=1 ./build.sh` adds a Finder-only appearance override
after signing and verification. Finder writes extended attributes and a resource
fork, which strict signature verification rejects. This override is not used for
notification validation or distribution. Default builds retain a valid signature.

## Legacy notification identity migration

On the affected macOS 27.2 installation, the same minimal AppKit notifier and
bundled artwork displayed blue under an independent bundle ID, but displayed the
placeholder under `com.antigravity.TimeTracker`, including at the installed app's
original path. Restarting notification and icon services did not change that
result. The exact internal stale record could not be read because it is protected.

The app now uses the stable ID `com.antigravity.TimeTracker.macOS`. Before creating
its state model, it imports legacy preferences once, preserving values already
saved under the new ID. History remains in the existing Application Support
folder. Notification permission belongs to the new identity and must be granted
again. A previously enabled login item is restored using the public SMAppService
API. During this local upgrade, the old login item is retired before replacement.

The user confirmed that the full app's 1.1 (5) test notification displays the blue
icon under the new identity, and confirmed that it remains blue after updating to
1.1 (6). The login item was restored to the enabled state. Resource/signature
checks alone are not treated as proof of Notification Center rendering.
