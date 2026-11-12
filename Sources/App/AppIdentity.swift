import Foundation
import ServiceManagement

/// Keep one stable identity after migrating away from the legacy notification entry.
enum AppIdentity {
    static let identifier = "com.antigravity.TimeTracker.macOS"
    static let legacyIdentifier = "com.antigravity.TimeTracker"
    private static let migrationKey = "legacyAppIdentityPreferencesMigrated"
    private static let restoreLoginKey = "restoreLoginItemAfterIdentityMigration"

    static func prepareForLaunch() {
        guard Bundle.main.bundleIdentifier == identifier else { return }
        migratePreferences(defaults: .standard, from: legacyIdentifier, to: identifier)
    }

    /// Import once, keeping any preferences already saved under the new identity.
    static func migratePreferences(defaults: UserDefaults, from legacyID: String, to currentID: String) {
        var current = defaults.persistentDomain(forName: currentID) ?? [:]
        guard current[migrationKey] as? Bool != true else { return }
        let legacy = defaults.persistentDomain(forName: legacyID) ?? [:]
        let shouldRestoreLogin = (current["launchAtLogin"] ?? legacy["launchAtLogin"]) as? Bool == true
        for (key, value) in legacy where current[key] == nil {
            current[key] = value
        }
        current[migrationKey] = true
        if shouldRestoreLogin { current[restoreLoginKey] = true }
        defaults.setPersistentDomain(current, forName: currentID)
    }

    static func restoreLoginItemIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: restoreLoginKey) else { return }
        if #available(macOS 13.0, *) {
            do {
                switch SMAppService.mainApp.status {
                case .notRegistered, .notFound:
                    try SMAppService.mainApp.register()
                case .enabled, .requiresApproval:
                    break
                @unknown default:
                    return
                }
                defaults.removeObject(forKey: restoreLoginKey)
                print("Login item after identity migration: \(SMAppService.mainApp.status.rawValue)")
                fflush(stdout)
            } catch {
                print("Failed to restore login item after identity migration: \(error)")
                fflush(stdout)
            }
        }
    }
}
