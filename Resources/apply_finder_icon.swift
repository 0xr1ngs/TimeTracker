import AppKit
import Foundation

// Optional local appearance override, matching the reference app in Finder.
// Keep this outside signed release builds: Finder writes extended attributes.
let arguments = CommandLine.arguments
guard arguments.count == 3,
      let image = NSImage(contentsOfFile: arguments[1]) else {
    fatalError("Usage: swift Resources/apply_finder_icon.swift <icon.icns> <app-path>")
}
let app = URL(fileURLWithPath: arguments[2]).standardizedFileURL
if !NSWorkspace.shared.setIcon(image, forFile: app.path, options: []) {
    fatalError("Finder could not apply the custom icon")
}
print("Applied the reference Finder icon to \(app.path)")
