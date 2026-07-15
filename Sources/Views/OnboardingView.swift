import SwiftUI
import UserNotifications
import ServiceManagement

struct OnboardingView: View {
    @ObservedObject var timeManager: TimeManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var notificationsGranted = false
    @State private var launchAtLoginEnabled = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "timer")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.blue)
                .padding(.top, 40)
                .accessibilityLabel(Text("App Icon"))
            
            VStack(spacing: 8) {
                Text("欢迎使用 Time Tracker")
                    .font(.system(size: 28, weight: .bold))
                
                Text("智能无感的 macOS 时间追踪工具")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "lock.open.display", color: .blue, title: "无感记录", description: "解锁自动开始工作，锁屏自动进入休息。")
                FeatureRow(icon: "menubar.rectangle", color: .purple, title: "状态驻留", description: "彻底告别 Dock 栏，在菜单栏随时查看今日状态。")
                FeatureRow(icon: "figure.walk.circle.fill", color: .orange, title: "久坐提醒", description: "长时间工作后，准时提醒您起身活动。")
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    requestNotificationPermission()
                }) {
                    HStack {
                        Image(systemName: notificationsGranted ? "checkmark.circle.fill" : "bell.badge.fill")
                        Text(notificationsGranted ? "已授权通知" : "允许发送通知")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(notificationsGranted ? .green : .blue)
                .disabled(notificationsGranted)
                .accessibilityHint("点击以授予发送系统通知的权限")
                
                if #available(macOS 13.0, *) {
                    Button(action: {
                        toggleLaunchAtLogin()
                    }) {
                        HStack {
                            Image(systemName: launchAtLoginEnabled ? "checkmark.circle.fill" : "macwindow.badge.plus")
                            Text(launchAtLoginEnabled ? "已开启开机自启" : "开启开机自动启动")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(launchAtLoginEnabled ? .green : .primary)
                    .accessibilityHint("点击以开启开机自动启动")
                }
                
                Button("开始使用") {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    NSApp.windows.filter { $0.title == "欢迎" }.forEach { $0.close() }
                    WindowManager.shared.openDashboardWindow(timeManager: timeManager)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .padding(.top, 8)
                .accessibilityHint("点击以完成设置并打开控制中心")
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .frame(width: 450, height: 600)
        .background(VisualEffectBlur(material: .windowBackground, blendingMode: .behindWindow))
        .onAppear {
            checkPermissions()
        }
    }
    
    func checkPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsGranted = (settings.authorizationStatus == .authorized)
            }
        }
        if #available(macOS 13.0, *) {
            self.launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.notificationsGranted = granted
            }
        }
    }
    
    func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    launchAtLoginEnabled = false
                    timeManager.launchAtLogin = false
                } else {
                    try SMAppService.mainApp.register()
                    launchAtLoginEnabled = true
                    timeManager.launchAtLogin = true
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}
