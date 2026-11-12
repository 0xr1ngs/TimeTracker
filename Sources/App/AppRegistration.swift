import AppKit
import CoreServices

/// Register the bundle's own icon before notification permission and delivery.
/// Finder custom icons are intentionally not used to validate notification icons.
enum AppRegistration {
    @discardableResult
    static func registerForNotifications(bundle: Bundle = .main) -> Bool {
        guard bundle.bundleURL.pathExtension == "app",
              let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
              let resources = bundle.resourceURL else { return false }
        let fileName = (iconName as NSString).pathExtension.isEmpty ? iconName + ".icns" : iconName
        let iconURL = resources.appendingPathComponent(fileName)
        guard let icon = NSImage(contentsOf: iconURL), icon.isValid else {
            print("Notification icon is missing or unreadable: \(fileName)")
            return false
        }
        if let assetName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String {
            guard FileManager.default.fileExists(atPath: resources.appendingPathComponent("Assets.car").path) else {
                print("Notification icon catalog is missing for asset: \(assetName)")
                return false
            }
        }
        let status = LSRegisterURL(bundle.bundleURL as CFURL, true)
        if status != noErr {
            print("Failed to refresh application registration for notifications: \(status)")
        }
        return status == noErr
    }
}
