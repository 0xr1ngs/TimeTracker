# Installed reference icon

`AppIconReference.icns` is extracted without redrawing from the custom Finder icon
resource of `/Applications/TimeTracker.app/Icon\r` selected by the user.
`AppIconReference.png` is its original 1024-pixel representation. The matching
`AppIconReference.appiconset` supplies the Xcode build.

The system renders ordinary bundled app icons differently from Finder custom
icons. To match the installed reference in a **local** build:

```sh
MATCH_REFERENCE_FINDER_ICON=1 ./build.sh
```

The script first signs and verifies the normal app bundle, then uses the public
`NSWorkspace.setIcon` API for the local Finder appearance. This last step adds
Finder metadata and a resource fork, which strict `codesign --verify` rejects.
It does not change the executable. Keep the option off for distribution; the
normal release bundle retains a valid signature and uses the bundled reference
icon. No source application or user records are modified.
