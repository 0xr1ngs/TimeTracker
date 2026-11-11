import SwiftUI
import AppKit

import UserNotifications

class WindowManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WindowManager()
    
    var dashboardWindow: NSWindow?
    var popupWindow: NSWindow?
    var onboardingWindow: NSWindow?
    weak var timeManager: TimeManager?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.categoryIdentifier == "rest-reminder",
           notification.request.content.userInfo["level"] as? String == "strong" {
            completionHandler([.list])
        } else {
            completionHandler([.banner, .list, .sound])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            if let manager = self.timeManager {
                if response.actionIdentifier == "start-rest" { manager.beginRest() }
                else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                    self.openDashboardWindow(timeManager: manager)
                }
            }
            completionHandler()
        }
    }

    func openDashboardWindow(timeManager: TimeManager) {
        if dashboardWindow == nil {
            let dashboardView = MainDashboardView(timeManager: timeManager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 660),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentMinSize = NSSize(width: 600, height: 580)
            window.center()
            window.setFrameAutosaveName("Dashboard Window Compact")
            window.title = "Time Tracker"
            window.contentView = NSHostingView(rootView: dashboardView)
            window.isReleasedWhenClosed = false
            self.dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showRestPopup(timeManager: TimeManager) {
        let panel: NSPanel
        if let existing = popupWindow as? NSPanel {
            panel = existing
        } else {
            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
            )
            panel.title = "休息提醒"
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            popupWindow = panel
        }
        panel.contentView = NSHostingView(rootView: RestPopupView(timeManager: timeManager))
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
        }
        // Stay visible without activating the app or taking keyboard focus.
        panel.orderFrontRegardless()
        if !timeManager.isReminderPreview { NSSound(named: NSSound.Name("Glass"))?.play() }
    }

    func hideRestPopup() {
        popupWindow?.orderOut(nil)
    }

    func showOnboardingWindow(timeManager: TimeManager) {
        if onboardingWindow == nil {
            let view = OnboardingView(timeManager: timeManager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "欢迎"
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.level = .floating
            self.onboardingWindow = window
        }
        
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct TimeTrackerApp: App {
    @StateObject private var timeManager = TimeManager()
    
    init() {
        // Install the notification delegate before any windows are opened.
        _ = WindowManager.shared
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowRestPopup"), object: nil, queue: .main) { notification in
            guard let manager = notification.object as? TimeManager else { return }
            WindowManager.shared.showRestPopup(timeManager: manager)
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("DismissRestPopup"), object: nil, queue: .main) { _ in
            WindowManager.shared.hideRestPopup()
        }
        // Removed onboarding logic from here to avoid mutating self capture
    }

    var body: some Scene {
        MenuBarExtra {
            Button("控制中心") {
                WindowManager.shared.openDashboardWindow(timeManager: timeManager)
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Text(timeManager.formatTimeInterval(timeManager.currentSessionElapsed))
        }
    }
}
