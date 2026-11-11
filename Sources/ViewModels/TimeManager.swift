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
        let isEN = UserDefaults.standard.string(forKey: "appLanguage") == "en"
        switch self {
        case .short: return isEN ? "Short (2h 15m)" : "简短（2h 15m）"
        case .digital: return isEN ? "Digital (02:15)" : "数字（02:15）"
        case .minutes: return isEN ? "Minutes (135m)" : "分钟（135m）"
        }
    }
}

class TimeManager: ObservableObject {
    @Published var statusText: String = "..."
    @Published var totalWorkTimeToday: TimeInterval = 0
    @Published var totalRestTimeToday: TimeInterval = 0
    @Published var isWorking: Bool = true
    @Published var currentSessionElapsed: TimeInterval = 0
    @Published var isRestReminderPresented = false
    @Published var isReminderPreview = false
    @Published var isLunchBreakExempt = false
    @Published private(set) var reminderSchedule = RestReminderSchedule()

    var nextReminderRemaining: TimeInterval {
        max(0, reminderSchedule.nextThreshold(elapsed: currentSessionElapsed) - currentSessionElapsed)
    }

    var focusProgress: Double {
        focusDuration > 0 ? min(1, max(0, focusTimeRemaining / focusDuration)) : 0
    }
    
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
    @AppStorage("restReminderEnabled") var restReminderEnabled: Bool = false {
        didSet {
            if !restReminderEnabled { resetReminderState() }
        }
    }
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
    private let servicesEnabled: Bool
    private var timer: Timer?
    private var currentDateString: String = ""

    private lazy var fileURL: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = urls[0].appendingPathComponent("com.antigravity.TimeTracker")
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        return appSupportDir.appendingPathComponent("records.json")
    }()

    init(startServices: Bool = true) {
        servicesEnabled = startServices
        self.currentDateString = TimeManager.getDateString(for: Date())
        
        guard startServices else { return }

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
        let center = UNUserNotificationCenter.current()
        WindowManager.shared.timeManager = self
        let restAction = UNNotificationAction(identifier: "start-rest", title: appLanguage == "en" ? "Start break" : "开始休息", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: "rest-reminder", actions: [restAction], intentIdentifiers: [], options: [])])
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error { print("Notification authorization failed: \(error)") }
        }
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
            resetReminderState()
            updateStatusText()
        }
    }

    func handleScreenUnlocked() {
        if !isWorking {
            isWorking = true
            currentSessionStartTime = Date()
            resetReminderState()
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
        resetReminderState()
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
                    if !isLunchBreakExempt {
                        isLunchBreakExempt = true
                        resetReminderState()
                    }
                    currentSessionStartTime = now
                    currentSessionElapsed = 0
                    statusText = isEN ? "Lunch Break" : "午休中 ☕️"
                    saveCurrentSession()
                    return // Bypasses both work and rest incrementation!
                }
            }
        }
        
        if isLunchBreakExempt {
            isLunchBreakExempt = false
            currentSessionStartTime = now
            resetReminderState()
        }
        currentSessionElapsed = max(0, now.timeIntervalSince(currentSessionStartTime))
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
            statusText = (isEN ? "Resting (" : "休息中 (") + formatTimeInterval(sessionElapsed) + ")"
        }
        
        saveCurrentSession()
    }

    func checkReminders(sessionElapsed: TimeInterval) {
        currentSessionElapsed = max(0, sessionElapsed)
        guard let level = reminderSchedule.nextReminder(elapsed: sessionElapsed, enabled: restReminderEnabled, isWorking: isWorking) else { return }
        switch level {
        case .gentle:
            sendRestNotification(sessionElapsed: sessionElapsed, level: .gentle)
        case .strong:
            sendRestNotification(sessionElapsed: sessionElapsed, level: .strong)
            isReminderPreview = false
            isRestReminderPresented = true
            NotificationCenter.default.post(name: .init("ShowRestPopup"), object: self)
        }
    }

    static func restReminderContent(sessionElapsed: TimeInterval, level: RestReminderLevel, language: String) -> UNMutableNotificationContent {
        let isEN = language == "en"
        let content = UNMutableNotificationContent()
        content.title = level == .strong ? (isEN ? "Time to recharge" : "该起身休息了") : (isEN ? "Time for a short break" : "给自己一个小休息")
        let minutes = Int(max(0, sessionElapsed) / 60)
        content.body = isEN ? "You have worked for \(minutes) minutes. Look away from the screen and stretch." : "已经连续工作 \(minutes) 分钟，看看远处，伸展一下吧。"
        content.categoryIdentifier = "rest-reminder"
        content.userInfo = ["level": level == .strong ? "strong" : "gentle"]
        // Keep Notification Center current while the strong panel supplies the alert.
        content.interruptionLevel = level == .strong ? .passive : .active
        return content
    }

    private func sendRestNotification(sessionElapsed: TimeInterval, level: RestReminderLevel) {
        guard servicesEnabled else { return }
        let content = Self.restReminderContent(sessionElapsed: sessionElapsed, level: level, language: appLanguage)
        let request = UNNotificationRequest(identifier: "rest-reminder", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Failed to deliver rest reminder: \(error)") }
        }
    }

    func beginRest() {
        if isFocusModeActive { stopFocusMode() }
        if isWorking { toggleWorkStatus() }
        else { resetReminderState() }
    }

    func snoozeRestReminder() {
        reminderSchedule.snooze(elapsed: currentSessionElapsed)
        hideRestReminder()
    }

    func previewRestReminder() {
        isReminderPreview = true
        isRestReminderPresented = true
        NotificationCenter.default.post(name: .init("ShowRestPopup"), object: self)
    }

    func hideRestReminder() {
        isRestReminderPresented = false
        isReminderPreview = false
        NotificationCenter.default.post(name: .init("DismissRestPopup"), object: self)
    }

    private func resetReminderState() {
        currentSessionElapsed = 0
        reminderSchedule.reset()
        hideRestReminder()
        if servicesEnabled {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["rest-reminder"])
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
            resetReminderState()
            currentSessionStartTime = Date()
        }
    }

    func saveCurrentSession() {
        guard servicesEnabled else { return }
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
        if !isWorking { toggleWorkStatus() }
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
        guard servicesEnabled else {
            return (0..<max(0, days)).reversed().map { offset in
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                return DailyRecord(dateString: Self.getDateString(for: date), totalWorkTime: 0, totalRestTime: 0)
            }
        }
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
