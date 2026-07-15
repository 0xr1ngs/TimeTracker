import SwiftUI
import AppKit

import UserNotifications

class WindowManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WindowManager()
    
    var dashboardWindow: NSWindow?
    var popupWindow: NSWindow?
    var onboardingWindow: NSWindow?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Force the notification to show as a banner even if the app is active
        completionHandler([.banner, .sound])
    }
    
    func openDashboardWindow(timeManager: TimeManager) {
        if dashboardWindow == nil {
            let dashboardView = MainDashboardView(timeManager: timeManager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("Dashboard Window")
            window.title = "Time Tracker"
            window.contentView = NSHostingView(rootView: dashboardView)
            window.isReleasedWhenClosed = false
            self.dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showRestPopup() {
        if popupWindow == nil {
            let popupView = RestPopupView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "休息提醒"
            window.contentView = NSHostingView(rootView: popupView)
            window.isReleasedWhenClosed = false
            window.level = .floating
            self.popupWindow = window
        }
        
        popupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowRestPopup"), object: nil, queue: .main) { _ in
            WindowManager.shared.showRestPopup()
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
            Text(timeManager.statusText)
        }
    }
}
