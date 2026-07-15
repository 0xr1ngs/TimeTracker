import SwiftUI

struct SettingsView: View {
    @ObservedObject var timeManager: TimeManager
    
    // Accordion expansion states
    @State private var expandedGoal: String? = nil
    @State private var expandedLunchStart: Bool = false
    @State private var expandedLunchEnd: Bool = false
    
    // Copy clipboard status flags
    @State private var copiedOn: Bool = false
    @State private var copiedOff: Bool = false
    
    private var isEN: Bool { timeManager.appLanguage == "en" }
    
    // Lunch options range restricted from 10:00 to 16:00 (30-minute stepping)
    private let startOptions: [Double] = Array(stride(from: 10.0, through: 15.0, by: 0.5)) // 10:00 - 15:00
    private let endOptions: [Double] = Array(stride(from: 11.0, through: 16.0, by: 0.5))   // 11:00 - 16:00
    
    // Clean 4-column grid layout for compact fit
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        Form {
            Section {
                Picker(selection: $timeManager.timeFormat, label: HStack {
                    Image(systemName: "clock.fill").foregroundColor(.blue)
                    Text(isEN ? "Time Format" : "时间显示格式")
                }) {
                    ForEach(TimeFormat.allCases) { format in
                        Text(format.description).tag(format)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .id("formatPicker_\(timeManager.appLanguage)")
                
                Picker(selection: $timeManager.appLanguage, label: HStack {
                    Image(systemName: "character.bubble.fill").foregroundColor(.cyan)
                    Text(isEN ? "Language" : "界面显示语言")
                }) {
                    Text("简体中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(MenuPickerStyle())
            } header: {
                Text(isEN ? "Appearance & Locale 🌐" : "外观与本地化 🌐")
            }
            
            Section {
                // Work Goal
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring()) {
                            expandedGoal = (expandedGoal == "work" ? nil : "work")
                        }
                    }) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "laptopcomputer").foregroundColor(.blue).frame(width: 18)
                                Text(isEN ? "Work Goal" : "工作目标")
                            }
                            Spacer()
                            
                            Text(formatGoal(timeManager.workGoalHours, unit: "h"))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if expandedGoal == "work" {
                        HStack {
                            Slider(value: $timeManager.workGoalHours, in: 1...24, step: 0.5)
                                .tint(.blue)
                            Text(isEN ? "Drag Slider" : "滑动调整目标")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 26)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Rest Goal
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring()) {
                            expandedGoal = (expandedGoal == "rest" ? nil : "rest")
                        }
                    }) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "cup.and.saucer.fill").foregroundColor(.green).frame(width: 18)
                                Text(isEN ? "Rest Goal" : "休息目标")
                            }
                            Spacer()
                            
                            Text("\(Int(timeManager.restGoalMinutes)) m")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if expandedGoal == "rest" {
                        HStack {
                            Slider(value: $timeManager.restGoalMinutes, in: 5...300, step: 5)
                                .tint(.green)
                            Text(isEN ? "Drag Slider" : "滑动调整目标")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 26)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Focus Goal
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring()) {
                            expandedGoal = (expandedGoal == "focus" ? nil : "focus")
                        }
                    }) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile").foregroundColor(.purple).frame(width: 18)
                                Text(isEN ? "Focus Goal" : "专注目标")
                            }
                            Spacer()
                            
                            Text(isEN ? "\(timeManager.focusGoalSessions) times" : "\(timeManager.focusGoalSessions) 次")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if expandedGoal == "focus" {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(timeManager.focusGoalSessions) },
                                set: { timeManager.focusGoalSessions = Int($0) }
                            ), in: 1...20, step: 1)
                            .tint(.purple)
                            Text(isEN ? "Drag Slider" : "滑动调整目标")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 26)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } header: {
                Text(isEN ? "Daily Goals (Click Row to Edit) 🎯" : "每日目标设定 (点击行展开滑动条) 🎯")
            }
            
            Section {
                Toggle(isOn: $timeManager.idleDetectionEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill").foregroundColor(.indigo)
                        Text(isEN ? "Idle Auto-Detection" : "自动闲置判定")
                    }
                }
                
                if timeManager.idleDetectionEnabled {
                    HStack {
                        Text(isEN ? "Idle interval before rest" : "无操作多久后判定为休息？")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Spacer()
                        Stepper(value: $timeManager.idleDetectionInterval, in: 1...60, step: 1) {
                            Text(isEN ? "\(Int(timeManager.idleDetectionInterval)) mins" : "\(Int(timeManager.idleDetectionInterval)) 分钟")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding(.leading, 26)
                }
                
                Toggle(isOn: $timeManager.lunchBreakEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill").foregroundColor(.orange)
                        Text(isEN ? "Lunch Break Interval" : "午休自动免记录")
                    }
                }
                
                if timeManager.lunchBreakEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        
                        // Custom 4-Column Grid for Lunch Start Hour (Finer 30m granularity)
                        VStack(alignment: .leading, spacing: 6) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    expandedLunchStart.toggle()
                                    if expandedLunchStart { expandedLunchEnd = false }
                                }
                            }) {
                                HStack {
                                    Text(isEN ? "Lunch Start Time" : "午休开始时间")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text(formatLunchTime(timeManager.lunchStartHour))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .buttonStyle(.plain)
                            
                            if expandedLunchStart {
                                LazyVGrid(columns: gridColumns, spacing: 6) {
                                    ForEach(startOptions, id: \.self) { val in
                                        Button(action: {
                                            timeManager.lunchStartHour = val
                                        }) {
                                            Text(formatLunchTime(val))
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(timeManager.lunchStartHour == val ? .white : .primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 6)
                                                .background(timeManager.lunchStartHour == val ? Color.orange.gradient : Color.primary.opacity(0.06).gradient)
                                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Custom 4-Column Grid for Lunch End Hour (Finer 30m granularity)
                        VStack(alignment: .leading, spacing: 6) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    expandedLunchEnd.toggle()
                                    if expandedLunchEnd { expandedLunchStart = false }
                                }
                            }) {
                                HStack {
                                    Text(isEN ? "Lunch End Time" : "午休结束时间")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text(formatLunchTime(timeManager.lunchEndHour))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .buttonStyle(.plain)
                            
                            if expandedLunchEnd {
                                LazyVGrid(columns: gridColumns, spacing: 6) {
                                    ForEach(endOptions, id: \.self) { val in
                                        Button(action: {
                                            timeManager.lunchEndHour = val
                                        }) {
                                            Text(formatLunchTime(val))
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(timeManager.lunchEndHour == val ? .white : .primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 6)
                                                .background(timeManager.lunchEndHour == val ? Color.orange.gradient : Color.primary.opacity(0.06).gradient)
                                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.leading, 26)
                }
            } header: {
                Text(isEN ? "Smart Logic 🧠" : "智能分析与判定 🧠")
            }
            
            Section {
                Toggle(isOn: $timeManager.restReminderEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk.circle.fill").foregroundColor(.orange)
                        Text(isEN ? "Sedentary Reminder" : "开启久坐提醒")
                    }
                }
                
                if timeManager.restReminderEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(isEN ? "Continuous work threshold" : "连续工作多久后提醒？")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                            Spacer()
                            Text(isEN ? "\(Int(timeManager.restReminderInterval)) mins" : "\(Int(timeManager.restReminderInterval)) 分钟")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Slider(value: $timeManager.restReminderInterval, in: 5...120, step: 5)
                            .tint(.orange)
                        
                        HStack {
                            Text(isEN ? "Reminder Style" : "提醒方式")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $timeManager.reminderStyle) {
                                ForEach(ReminderStyle.allCases) { style in
                                    Text(style.description).tag(style)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 150)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.leading, 26)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            } header: {
                Text(isEN ? "Health Guard ☕️" : "健康守护 ☕️")
            }
            
            Section {
                Toggle(isOn: $timeManager.syncMacOSFocus) {
                    HStack(spacing: 8) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill").foregroundColor(.teal)
                        Text(isEN ? "Sync macOS Focus (DND)" : "联动系统专注模式")
                    }
                }
                
                if timeManager.syncMacOSFocus {
                    VStack(alignment: .leading, spacing: 10) {
                        
                        // Beautiful step-by-step visual cookbook!
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isEN ? "⚡️ Foolproof 10-Second Setup Guide:" : "⚡️ 极简 10 秒免操作指南：")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("1️⃣")
                                    Text(isEN ? "Click button below. In Shortcuts App, click the top '+' icon to create a new shortcut." : "点击下方按钮打开系统「快捷指令」，在顶部菜单栏点击「+」加号新建指令。")
                                }
                                
                                // FocusOn row with instant Copy
                                HStack(alignment: .top, spacing: 4) {
                                    Text("2️⃣")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(isEN ? "Name it exactly: FocusOn. Search \"Set Focus\" on the right, drag in, and set to \"Turn Do Not Disturb On\"." : "创建第一个：命名为 `FocusOn`，并在右侧搜索「设定专注模式」拖拽进来，设为「开启勿扰模式」。")
                                        
                                        Button(action: {
                                            let pb = NSPasteboard.general
                                            pb.clearContents()
                                            pb.setString("FocusOn", forType: .string)
                                            copiedOn = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedOn = false }
                                        }) {
                                            Label(copiedOn ? (isEN ? "Copied!" : "已复制！") : (isEN ? "Copy 'FocusOn' name" : "📋 点击复制 'FocusOn' 名字"), systemImage: "doc.on.doc.fill")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                                
                                // FocusOff row with instant Copy
                                HStack(alignment: .top, spacing: 4) {
                                    Text("3️⃣")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(isEN ? "Name another: FocusOff. Search \"Set Focus\" on the right, drag in, and set to \"Turn Do Not Disturb Off\"." : "创建第二个：命名为 `FocusOff`，同样拖入「设定专注模式」，但设为「关闭勿扰模式」。")
                                        
                                        Button(action: {
                                            let pb = NSPasteboard.general
                                            pb.clearContents()
                                            pb.setString("FocusOff", forType: .string)
                                            copiedOff = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedOff = false }
                                        }) {
                                            Label(copiedOff ? (isEN ? "Copied!" : "已复制！") : (isEN ? "Copy 'FocusOff' name" : "📋 点击复制 'FocusOff' 名字"), systemImage: "doc.on.doc.fill")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                                
                                HStack(alignment: .top, spacing: 4) {
                                    Text("4️⃣")
                                    Text(isEN ? "All set! The app will automatically sync Do Not Disturb state when you focus." : "搞定！App 在开启和结束专注时将全自动托管开启/关闭系统勿扰。")
                                }
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "shortcuts://")!) // Open app root, safer for standard plus adding
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.forward.app.fill")
                                Text(isEN ? "Open Shortcuts App" : "🟢 一键打开快捷指令 App")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.gradient)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 26)
                    .padding(.top, 4)
                }
                
                if #available(macOS 13.0, *) {
                    Toggle(isOn: $timeManager.launchAtLogin) {
                        HStack(spacing: 8) {
                            Image(systemName: "macwindow.badge.plus").foregroundColor(.green)
                            Text(isEN ? "Launch at Login" : "开机自动启动")
                        }
                    }
                }
            } header: {
                Text(isEN ? "System & Integrations ⚙️" : "系统与集成 ⚙️")
            }
            
            Section {
                Button(action: {
                    timeManager.exportData()
                }) {
                    Label(isEN ? "Export History (CSV)" : "导出所有历史数据 (CSV)", systemImage: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            } header: {
                Text(isEN ? "Data Management 📁" : "数据管理 📁")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func formatGoal(_ val: Double, unit: String) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(val)) \(unit)"
        }
        return String(format: "%.1f %@", val, unit)
    }
    
    // Formatting lunch times to double format: 12.5 -> 12:30, 12.0 -> 12:00
    private func formatLunchTime(_ val: Double) -> String {
        let hour = Int(val)
        let mins = val.truncatingRemainder(dividingBy: 1) == 0 ? "00" : "30"
        return String(format: "%02d:%@", hour, mins)
    }
}
