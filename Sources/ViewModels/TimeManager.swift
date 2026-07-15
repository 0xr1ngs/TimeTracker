import Foundation
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import UniformTypeIdentifiers

struct DailyRecord: Codable {
    var dateString: String
    var totalWorkTime: TimeInterval
    var totalRestTime: TimeInterval
    var focusSessionsCompleted: Int?
    var totalFocusTime: TimeInterval?
    var workAM: TimeInterval?
    var workPM: TimeInterval?
    var restAM: TimeInterval?
    var restPM: TimeInterval?
}

enum TimeFormat: String, CaseIterable, Identifiable {
    case short = "short"     // 2h 15m
    case digital = "digital" // 02:15
    case minutes = "minutes" // 135m
    
    var id: String { self.rawValue }
    var description: String {
        switch self {
        case .short: return NSLocalizedString("Short (2h 15m)", comment: "")
        case .digital: return NSLocalizedString("Digital (02:15)", comment: "")
        case .minutes: return NSLocalizedString("Minutes (135m)", comment: "")
        }
    }
}

enum ReminderStyle: String, CaseIterable, Identifiable {
    case notification = "notification"
    case popup = "popup"
    
    var id: String { self.rawValue }
    var description: String {
        let isEN = UserDefaults.standard.string(forKey: "appLanguage") == "en"
        switch self {
        case .notification: return isEN ? "System Notification" : "系统通知"
        case .popup: return isEN ? "Center Popup" : "居中弹窗"
        }
    }
}

class TimeManager: ObservableObject {
    @Published var statusText: String = "..."
    @Published var totalWorkTimeToday: TimeInterval = 0
    @Published var totalRestTimeToday: TimeInterval = 0
    @Published var isWorking: Bool = true
    
    // Focus Mode
    @Published var isFocusModeActive: Bool = false
    @Published var focusTimeRemaining: TimeInterval = 0
    @Published var focusSessionsCompletedToday: Int = 0
    @Published var totalFocusTimeToday: TimeInterval = 0
    private var focusDuration: TimeInterval = 0
    private var focusTimer: Timer?
    private var lastTickTime: Date = Date()
    
    // Time distribution split
    @Published var workAMToday: TimeInterval = 0
    @Published var workPMToday: TimeInterval = 0
    @Published var restAMToday: TimeInterval = 0
    @Published var restPMToday: TimeInterval = 0
    
    // User Settings
    @AppStorage("timeFormat") var timeFormat: TimeFormat = .short
    @AppStorage("restReminderEnabled") var restReminderEnabled: Bool = false
    @AppStorage("restReminderInterval") var restReminderInterval: Double = 45 // minutes
    @AppStorage("reminderStyle") var reminderStyle: ReminderStyle = .notification
    @AppStorage("workGoalHours") var workGoalHours: Double = 8.0
    @AppStorage("restGoalMinutes") var restGoalMinutes: Double = 60.0
    @AppStorage("focusGoalSessions") var focusGoalSessions: Int = 4
    
    // Advanced Settings
    @AppStorage("idleDetectionEnabled") var idleDetectionEnabled: Bool = false
    @AppStorage("idleDetectionInterval") var idleDetectionInterval: Double = 5 // minutes
    @AppStorage("lunchBreakEnabled") var lunchBreakEnabled: Bool = false
    // Migrated storage keys to Double to support 30m granularity without collisions
    @AppStorage("lunchStartHourDouble") var lunchStartHour: Double = 12.0
    @AppStorage("lunchEndHourDouble") var lunchEndHour: Double = 14.0
    @AppStorage("appLanguage") var appLanguage: String = "zh"
    @AppStorage("syncMacOSFocus") var syncMacOSFocus: Bool = false
    
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            toggleLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    private var currentSessionStartTime: Date = Date()
    private var lastReminderTime: Date?
    private var timer: Timer?
    private var currentDateString: String = ""

    private let fileURL: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = urls[0].appendingPathComponent("com.antigravity.TimeTracker")
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        return appSupportDir.appendingPathComponent("records.json")
    }()

    init() {
        self.currentDateString = TimeManager.getDateString(for: Date())
        
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        
        loadDailyData()
        setupObservers()
        setupNotifications()
        startTimer()
        
        DispatchQueue.main.async {
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                WindowManager.shared.showOnboardingWindow(timeManager: self)
            }
        }
    }

    static func getDateString(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        var targetDate = date
        if hour < 4 {
            targetDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: targetDate)
    }

    func setupObservers() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.handleScreenLocked()
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.handleScreenUnlocked()
        }
        
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.saveCurrentSession()
        }
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }

    func handleScreenLocked() {
        if isWorking {
            isWorking = false
            currentSessionStartTime = Date()
            lastReminderTime = nil
            updateStatusText()
        }
    }

    func handleScreenUnlocked() {
        if !isWorking {
            isWorking = true
            currentSessionStartTime = Date()
            updateStatusText()
        }
    }
    
    func startTimer() {
        lastTickTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.updateStatusText()
        }
        RunLoop.main.add(timer!, forMode: .common)
        updateStatusText()
    }
    
    func toggleWorkStatus() {
        isWorking.toggle()
        currentSessionStartTime = Date()
        lastReminderTime = nil
        updateStatusText()
    }
    
    func updateStatusText() {
        checkReset()
        
        let now = Date()
        let tickElapsed = now.timeIntervalSince(lastTickTime)
        lastTickTime = now
        
        let isEN = appLanguage == "en"
        
        // Idle Detection Check
        if idleDetectionEnabled && isWorking {
            let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
            if idleTime >= idleDetectionInterval * 60 {
                toggleWorkStatus()
                triggerIdleNotification()
                return
            }
        }
        
        // Lunch Break Auto-exemption Check
        if lunchBreakEnabled {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let currentHourDouble = Double(hour) + Double(minute) / 60.0
            
            if currentHourDouble >= lunchStartHour && currentHourDouble < lunchEndHour {
                // If focus mode is active, let focus mode run, but suspend normal tracking.
                if !isFocusModeActive {
                    statusText = isEN ? "Lunch Break (Exempt)" : "午休免记录中 ☕️"
                    saveCurrentSession()
                    return // Bypasses both work and rest incrementation!
                }
            }
        }
        
        let hour = Calendar.current.component(.hour, from: now)
        let isAM = hour < 12
        
        if isWorking {
            totalWorkTimeToday += tickElapsed
            if isAM {
                workAMToday += tickElapsed
            } else {
                workPMToday += tickElapsed
            }
            
            let sessionElapsed = now.timeIntervalSince(currentSessionStartTime)
            checkReminders(sessionElapsed: sessionElapsed)
            statusText = formatTimeInterval(sessionElapsed)
        } else {
            totalRestTimeToday += tickElapsed
            if isAM {
                restAMToday += tickElapsed
            } else {
                restPMToday += tickElapsed
            }
            
            let sessionElapsed = now.timeIntervalSince(currentSessionStartTime)
            statusText = "休息中 (" + formatTimeInterval(sessionElapsed) + ")"
        }
        
        saveCurrentSession()
    }

    func checkReminders(sessionElapsed: TimeInterval) {
        guard restReminderEnabled && isWorking else { return }
        
        let intervalSecs = restReminderInterval * 60
        if sessionElapsed >= intervalSecs {
            let timeSinceLastReminder = lastReminderTime.map { Date().timeIntervalSince($0) } ?? intervalSecs
            
            if timeSinceLastReminder >= intervalSecs {
                triggerReminder()
                lastReminderTime = Date()
            }
        } else {
            lastReminderTime = nil
        }
    }

    func triggerReminder() {
        let isEN = appLanguage == "en"
        if reminderStyle == .notification {
            let content = UNMutableNotificationContent()
            content.title = isEN ? "Rest Reminder ☕️" : "休息提醒 ☕️"
            content.body = isEN ? 
                "You have been working continuously for \(Int(restReminderInterval)) minutes. Take a break!" :
                "您已经连续工作了 \(Int(restReminderInterval)) 分钟，起来活动一下吧！"
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("ShowRestPopup"), object: nil)
        }
    }
    
    private func triggerIdleNotification() {
        let isEN = appLanguage == "en"
        let content = UNMutableNotificationContent()
        content.title = isEN ? "Idle Detected 💤" : "闲置判定 💤"
        content.body = isEN ? 
            "No activity detected for \(Int(idleDetectionInterval)) mins. Switched to rest status." :
            "检测到您已连续未操作达 \(Int(idleDetectionInterval)) 分钟，已自动为您记录为休息状态。"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        switch timeFormat {
        case .short:
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        case .digital:
            return String(format: "%02d:%02d", hours, minutes)
        case .minutes:
            let totalMins = Int(interval) / 60
            return "\(totalMins)m"
        }
    }

    func checkReset() {
        let newDateString = TimeManager.getDateString(for: Date())
        if newDateString != currentDateString {
            currentDateString = newDateString
            totalWorkTimeToday = 0
            totalRestTimeToday = 0
            focusSessionsCompletedToday = 0
            totalFocusTimeToday = 0
            workAMToday = 0
            workPMToday = 0
            restAMToday = 0
            restPMToday = 0
            lastReminderTime = nil
            currentSessionStartTime = Date()
        }
    }

    func saveCurrentSession() {
        var records: [String: DailyRecord] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existingRecords = try? JSONDecoder().decode([String: DailyRecord].self, from: data) {
            records = existingRecords
        }
        
        records[currentDateString] = DailyRecord(
            dateString: currentDateString,
            totalWorkTime: totalWorkTimeToday,
            totalRestTime: totalRestTimeToday,
            focusSessionsCompleted: focusSessionsCompletedToday,
            totalFocusTime: totalFocusTimeToday,
            workAM: workAMToday,
            workPM: workPMToday,
            restAM: restAMToday,
            restPM: restPMToday
        )
        
        if let encoded = try? JSONEncoder().encode(records) {
            try? encoded.write(to: fileURL)
        }
    }
    
    private func loadDailyData() {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([String: DailyRecord].self, from: data) else {
            return
        }
        
        if let todayRecord = records[currentDateString] {
            self.totalWorkTimeToday = todayRecord.totalWorkTime
            self.totalRestTimeToday = todayRecord.totalRestTime
            self.focusSessionsCompletedToday = todayRecord.focusSessionsCompleted ?? 0
            self.totalFocusTimeToday = todayRecord.totalFocusTime ?? 0
            self.workAMToday = todayRecord.workAM ?? 0
            self.workPMToday = todayRecord.workPM ?? 0
            self.restAMToday = todayRecord.restAM ?? 0
            self.restPMToday = todayRecord.restPM ?? 0
        }
    }
    
    // MARK: - Focus Mode Logic
    
    func startFocusMode(minutes: Int) {
        isFocusModeActive = true
        focusDuration = TimeInterval(minutes * 60)
        focusTimeRemaining = focusDuration
        
        if syncMacOSFocus {
            toggleDNDViaShortcuts(on: true)
        }
        
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateFocusTime()
        }
        RunLoop.main.add(focusTimer!, forMode: .common)
    }
    
    func stopFocusMode() {
        isFocusModeActive = false
        focusTimer?.invalidate()
        focusTimer = nil
        
        if syncMacOSFocus {
            toggleDNDViaShortcuts(on: false)
        }
    }
    
    private func updateFocusTime() {
        guard isFocusModeActive else { return }
        if focusTimeRemaining > 0 {
            focusTimeRemaining -= 1
        } else {
            stopFocusMode()
            triggerFocusEndNotification()
        }
    }
    
    private func triggerFocusEndNotification() {
        let isEN = appLanguage == "en"
        self.focusSessionsCompletedToday += 1
        self.totalFocusTimeToday += focusDuration
        self.saveCurrentSession()
        
        let content = UNMutableNotificationContent()
        content.title = isEN ? "Focus Complete 🎉" : "专注结束 🎉"
        content.body = isEN ? 
            "Congratulations on completing your focus! Stand up and stretch." : 
            "恭喜完成了一次专注，起来活动一下，喝口水吧！"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func toggleDNDViaShortcuts(on: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", on ? "FocusOn" : "FocusOff"]
        try? process.run()
    }
    
    func getRecordsForLast(days: Int) -> [DailyRecord] {
        var recordsList: [DailyRecord] = []
        saveCurrentSession()
        
        var dict: [String: DailyRecord] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existingRecords = try? JSONDecoder().decode([String: DailyRecord].self, from: data) {
            dict = existingRecords
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        for i in (0..<days).reversed() {
            if let targetDate = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateStr = TimeManager.getDateString(for: targetDate)
                if let record = dict[dateStr] {
                    recordsList.append(record)
                } else {
                    recordsList.append(DailyRecord(dateString: dateStr, totalWorkTime: 0, totalRestTime: 0))
                }
            }
        }
        
        return recordsList
    }
    
    func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "TimeTracker_Records.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        
        if panel.runModal() == .OK, let url = panel.url {
            var csv = "Date,Work Time (Hours),Rest Time (Hours)\n"
            if let data = try? Data(contentsOf: fileURL),
               let existingRecords = try? JSONDecoder().decode([String: DailyRecord].self, from: data) {
                
                let sortedKeys = existingRecords.keys.sorted()
                for key in sortedKeys {
                    if let record = existingRecords[key] {
                        let workH = String(format: "%.2f", record.totalWorkTime / 3600.0)
                        let restH = String(format: "%.2f", record.totalRestTime / 3600.0)
                        csv += "\(record.dateString),\(workH),\(restH)\n"
                    }
                }
            }
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
