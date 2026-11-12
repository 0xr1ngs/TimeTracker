import AppKit
import SwiftUI
import Foundation
import UserNotifications

@main
struct AppChecks {
    @MainActor static func main() throws {
        let legacyID = "TimeTracker.Tests.Legacy." + UUID().uuidString
        let currentID = "TimeTracker.Tests.Current." + UUID().uuidString
        let defaults = UserDefaults(suiteName: currentID)!
        defer {
            defaults.removePersistentDomain(forName: legacyID)
            defaults.removePersistentDomain(forName: currentID)
        }
        let legacy: [String: Any] = ["appLanguage": "zh", "workGoalHours": 7.5, "restReminderEnabled": true, "hasSeenOnboarding": true, "launchAtLogin": true]
        defaults.setPersistentDomain(legacy, forName: legacyID)
        defaults.setPersistentDomain(["appLanguage": "en"], forName: currentID)
        AppIdentity.migratePreferences(defaults: defaults, from: legacyID, to: currentID)
        assert(defaults.string(forKey: "appLanguage") == "en", "Existing new preferences must win")
        assert(defaults.double(forKey: "workGoalHours") == 7.5)
        assert(defaults.bool(forKey: "restReminderEnabled") && defaults.bool(forKey: "hasSeenOnboarding"))
        assert(defaults.bool(forKey: "restoreLoginItemAfterIdentityMigration"))
        assert(defaults.persistentDomain(forName: legacyID)?["workGoalHours"] as? Double == 7.5, "Keep legacy preferences available for rollback")
        defaults.removeObject(forKey: "restReminderEnabled")
        AppIdentity.migratePreferences(defaults: defaults, from: legacyID, to: currentID)
        assert(defaults.object(forKey: "restReminderEnabled") == nil, "Migration must not reimport old values on later launches")
        let disabledID = currentID + ".Disabled"
        defer { defaults.removePersistentDomain(forName: disabledID) }
        defaults.setPersistentDomain(["launchAtLogin": false], forName: disabledID)
        AppIdentity.migratePreferences(defaults: defaults, from: legacyID, to: disabledID)
        let disabled = defaults.persistentDomain(forName: disabledID)!
        assert(disabled["launchAtLogin"] as? Bool == false && disabled["restoreLoginItemAfterIdentityMigration"] == nil)
        print("PASS: identity migration preserves settings, existing choices, login preference and rollback data; runs once")

        UserDefaults.standard.setVolatileDomain([
            "restReminderEnabled": true, "idleDetectionEnabled": false,
            "lunchBreakEnabled": false, "appLanguage": "zh"
        ], forName: UserDefaults.argumentDomain)
        let gentle = TimeManager.restReminderContent(sessionElapsed: 1800, level: .gentle, language: "zh")
        assert(gentle.sound == nil && gentle.interruptionLevel == .active && gentle.body.contains("30 分钟"))
        let strong = TimeManager.restReminderContent(sessionElapsed: 3600, level: .strong, language: "zh")
        assert(strong.sound == nil && strong.interruptionLevel == .passive && strong.body.contains("60 分钟"))
        let later = TimeManager.restReminderContent(sessionElapsed: 5400, level: .strong, language: "en")
        assert(later.body.contains("90 minutes") && later.userInfo["level"] as? String == "strong")
        print("PASS: quiet 30-minute notification and current 60/90-minute Notification Center content")
        let iconPreview = TimeManager.notificationPreviewContent(language: "zh")
        assert(iconPreview.title == "通知图标测试" && iconPreview.sound == nil)
        assert(iconPreview.categoryIdentifier.isEmpty, "Icon previews must not offer a real rest action")
        let englishPreview = TimeManager.notificationPreviewContent(language: "en")
        assert(englishPreview.title == "Notification icon test")
        let manager = TimeManager(startServices: false)
        assert(manager.restReminderEnabled)
        var presentations = 0
        let observer = NotificationCenter.default.addObserver(forName: .init("ShowRestPopup"), object: manager, queue: nil) { _ in presentations += 1 }
        manager.checkReminders(sessionElapsed: 1799)
        assert(!manager.reminderSchedule.gentleDelivered)
        manager.checkReminders(sessionElapsed: 1800)
        assert(manager.reminderSchedule.gentleDelivered && !manager.isRestReminderPresented)
        manager.checkReminders(sessionElapsed: 3599)
        assert(presentations == 0)
        manager.checkReminders(sessionElapsed: 3600)
        assert(manager.isRestReminderPresented && presentations == 1)
        manager.checkReminders(sessionElapsed: 3602)
        assert(presentations == 1)
        manager.snoozeRestReminder()
        assert(!manager.isRestReminderPresented && manager.reminderSchedule.snoozedUntilElapsed == 4202)
        manager.checkReminders(sessionElapsed: 4201)
        assert(presentations == 1)
        manager.checkReminders(sessionElapsed: 4202)
        assert(presentations == 2 && manager.isRestReminderPresented)
        manager.beginRest()
        assert(!manager.isWorking && !manager.isRestReminderPresented)
        assert(manager.reminderSchedule.lastStrongElapsed == nil && manager.currentSessionElapsed < 1)
        manager.toggleWorkStatus()
        manager.checkReminders(sessionElapsed: 1800)
        assert(manager.reminderSchedule.gentleDelivered)
        manager.handleScreenLocked()
        assert(!manager.isWorking && !manager.reminderSchedule.gentleDelivered)
        manager.handleScreenUnlocked()
        assert(manager.isWorking && manager.currentSessionElapsed < 1)
        manager.previewRestReminder()
        assert(manager.isReminderPreview && manager.isRestReminderPresented)
        manager.hideRestReminder()
        assert(!manager.isRestReminderPresented && !manager.isReminderPreview)
        NotificationCenter.default.removeObserver(observer)
        print("PASS: real TimeManager escalation, snooze, new session, lock/unlock, preview and dismissal")

        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let preview = TimeManager(startServices: false)
        preview.totalWorkTimeToday = 3 * 3600 + 24 * 60
        preview.totalRestTimeToday = 35 * 60
        preview.focusSessionsCompletedToday = 3
        preview.workAMToday = 2 * 3600
        preview.workPMToday = 3600 + 24 * 60
        preview.restAMToday = 20 * 60
        preview.restPMToday = 15 * 60
        preview.checkReminders(sessionElapsed: 32 * 60 + 18)
        try render(MainDashboardView(timeManager: preview), width: 640, height: 660, dark: false, to: output.appendingPathComponent("dashboard-light.png"))
        try render(MainDashboardView(timeManager: preview), width: 600, height: 580, dark: true, to: output.appendingPathComponent("dashboard-dark-compact.png"))
        try render(MainDashboardView(timeManager: preview, initialTab: 1), width: 640, height: 660, dark: false, to: output.appendingPathComponent("focus-light.png"))
        try render(MainDashboardView(timeManager: preview, initialTab: 2), width: 640, height: 660, dark: false, to: output.appendingPathComponent("stats-light.png"))
        try render(MainDashboardView(timeManager: preview, initialTab: 3), width: 640, height: 660, dark: false, to: output.appendingPathComponent("settings-light.png"))
        preview.checkReminders(sessionElapsed: 67 * 60)
        try render(RestPopupView(timeManager: preview), width: 460, height: 380, dark: false, to: output.appendingPathComponent("reminder-light.png"))
        try render(RestPopupView(timeManager: preview), width: 460, height: 380, dark: true, to: output.appendingPathComponent("reminder-dark.png"))
        UserDefaults.standard.setVolatileDomain(["restReminderEnabled": true, "idleDetectionEnabled": false, "lunchBreakEnabled": false, "appLanguage": "en"], forName: UserDefaults.argumentDomain)
        let english = TimeManager(startServices: false)
        english.checkReminders(sessionElapsed: 3600)
        try render(MainDashboardView(timeManager: english), width: 600, height: 580, dark: false, to: output.appendingPathComponent("dashboard-english-compact.png"))
        try render(RestPopupView(timeManager: english), width: 460, height: 380, dark: false, to: output.appendingPathComponent("reminder-english.png"))
        print("PASS: rendered Chinese/English, light/dark and compact layouts to \(output.path)")
    }

    @MainActor static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, dark: Bool, to url: URL) throws {
        let frame = NSRect(x: 0, y: 0, width: width, height: height)
        let host = NSHostingView(rootView: view.environment(\.colorScheme, dark ? .dark : .light).frame(width: width, height: height))
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = frame
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("Cannot render view") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        window.close()
    }
}
