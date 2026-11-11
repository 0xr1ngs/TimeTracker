import SwiftUI

struct ReviewView: View {
    @ObservedObject var timeManager: TimeManager
    private var isEN: Bool { timeManager.appLanguage == "en" }
    private var overdue: Bool { timeManager.isWorking && timeManager.restReminderEnabled && timeManager.currentSessionElapsed >= 3600 }
    private var accent: Color { timeManager.isWorking ? (overdue ? .orange : .blue) : .green }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEN ? "Your day, at a glance" : "今天，节奏刚刚好")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text(isEN ? "A clear view of your work, breaks and focus." : "认真专注，也给自己留一点休息的时间。")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(timeManager.isLunchBreakExempt ? (isEN ? "LUNCH BREAK" : "午休免记录") : (timeManager.isWorking ? (isEN ? "CURRENT WORK SESSION" : "本次连续工作") : (isEN ? "CURRENT BREAK" : "本次休息")), systemImage: timeManager.isWorking ? "laptopcomputer" : "cup.and.saucer")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        Spacer()
                        if overdue {
                            Label(isEN ? "Break recommended" : "该休息一下了", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 11, weight: .medium)).foregroundColor(.orange)
                        }
                    }
                    HStack(alignment: .center) {
                        Text(clock(timeManager.currentSessionElapsed))
                            .font(.system(size: 40, weight: .medium, design: .rounded))
                            .monospacedDigit().foregroundColor(accent)
                            .accessibilityLabel(isEN ? "Current session duration" : "本次持续时长")
                        Spacer(minLength: 16)
                        Button {
                            if timeManager.isWorking { timeManager.beginRest() }
                            else { timeManager.toggleWorkStatus() }
                        } label: {
                            Label(timeManager.isWorking ? (isEN ? "Take a break" : "开始休息") : (isEN ? "Back to work" : "继续工作"), systemImage: timeManager.isWorking ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(PrimaryActionStyle(color: accent))
                    }
                    Divider().opacity(0.5)
                    HStack(spacing: 10) {
                        Image(systemName: timeManager.isWorking ? "bell.badge" : "leaf")
                            .foregroundColor(accent).font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reminderTitle).font(.system(size: 12, weight: .medium))
                            Text(reminderSubtitle).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        Spacer()
                        if timeManager.isWorking && timeManager.restReminderEnabled && !timeManager.isLunchBreakExempt {
                            Text(clock(timeManager.nextReminderRemaining))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit().foregroundColor(accent)
                        }
                    }
                }
                .dashboardCard(padding: 16)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.75))
                        .frame(width: 3, height: 42).padding(.leading, 1)
                }

                HStack(spacing: 20) {
                    ZStack {
                        progressRing(timeManager.totalWorkTimeToday / max(1, timeManager.workGoalHours * 3600), color: .blue, inset: 0)
                        progressRing(timeManager.totalRestTimeToday / max(1, timeManager.restGoalMinutes * 60), color: .green, inset: 16)
                        progressRing(Double(timeManager.focusSessionsCompletedToday) / Double(max(1, timeManager.focusGoalSessions)), color: .purple, inset: 32)
                        Image(systemName: "leaf.fill").font(.system(size: 23)).foregroundColor(.green.opacity(0.8))
                    }
                    .frame(width: 108, height: 108).padding(4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isEN ? "Daily work, rest and focus goals" : "今日工作、休息与专注目标进度")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isEN ? "A balanced day" : "今日时间分布").font(.system(size: 14, weight: .semibold))
                        timeline(title: isEN ? "Morning · before 12:00" : "上午 · 12:00 前", work: timeManager.workAMToday, rest: timeManager.restAMToday)
                        timeline(title: isEN ? "Afternoon · after 12:00" : "下午 · 12:00 后", work: timeManager.workPMToday, rest: timeManager.restPMToday)
                        HStack(spacing: 14) {
                            LegendItem(color: .blue, label: isEN ? "Work" : "工作")
                            LegendItem(color: .green, label: isEN ? "Rest" : "休息")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .dashboardCard(padding: 14)

                HStack(spacing: 12) {
                    GoalDetailCard(icon: "laptopcomputer", color: .blue, title: isEN ? "Work" : "工作时间", value: duration(timeManager.totalWorkTimeToday), goal: "\(timeManager.workGoalHours.formatted())h", progress: timeManager.totalWorkTimeToday / max(1, timeManager.workGoalHours * 3600), isEN: isEN)
                    GoalDetailCard(icon: "cup.and.saucer", color: .green, title: isEN ? "Rest" : "休息时间", value: duration(timeManager.totalRestTimeToday), goal: "\(Int(timeManager.restGoalMinutes))m", progress: timeManager.totalRestTimeToday / max(1, timeManager.restGoalMinutes * 60), isEN: isEN)
                    GoalDetailCard(icon: "brain.head.profile", color: .purple, title: isEN ? "Focus" : "专注次数", value: isEN ? "\(timeManager.focusSessionsCompletedToday) sessions" : "\(timeManager.focusSessionsCompletedToday) 次", goal: isEN ? "\(timeManager.focusGoalSessions) sessions" : "\(timeManager.focusGoalSessions) 次", progress: Double(timeManager.focusSessionsCompletedToday) / Double(max(1, timeManager.focusGoalSessions)), isEN: isEN)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 16).padding(.top, 4)
        }
    }

    private var reminderTitle: String {
        if timeManager.isLunchBreakExempt { return isEN ? "Enjoy your lunch break" : "安心午休，下午再继续" }
        if !timeManager.isWorking { return isEN ? "You are taking a break" : "休息也很重要" }
        if !timeManager.restReminderEnabled { return isEN ? "Rest reminders are off" : "休息提醒未开启" }
        if timeManager.isRestReminderPresented { return isEN ? "A break is waiting for you" : "现在是休息的好时机" }
        if timeManager.reminderSchedule.snoozedUntilElapsed != nil { return isEN ? "Reminder snoozed" : "已稍后提醒" }
        return isEN ? "Next rest reminder" : "距离下次休息提醒"
    }

    private var reminderSubtitle: String {
        if timeManager.isLunchBreakExempt { return isEN ? "Tracking and reminders are paused." : "此时段暂停计时和休息提醒。" }
        if !timeManager.isWorking { return isEN ? "Stretch, hydrate and rest your eyes." : "伸展一下、喝点水，看看远处。" }
        if !timeManager.restReminderEnabled { return isEN ? "Enable gentle and prominent reminders in Settings." : "可在设置中开启分级提醒。" }
        return isEN ? "30 min · quiet notification   60 min · break card" : "30 分钟轻提醒 · 60 分钟醒目提醒"
    }

    private func progressRing(_ progress: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.1), lineWidth: 10)
            Circle().trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.padding(inset)
    }

    private func timeline(title: String, work: TimeInterval, rest: TimeInterval) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).foregroundColor(.secondary)
                Spacer()
                Text(duration(work + rest)).monospacedDigit()
            }.font(.system(size: 11, weight: .medium))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.05))
                    HStack(spacing: 0) {
                        Color.blue.frame(width: geometry.size.width * work / max(1, work + rest))
                        Color.green.frame(width: geometry.size.width * rest / max(1, work + rest))
                    }.clipShape(Capsule())
                }
            }.frame(height: 7)
        }
    }

    private func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    private func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

struct GoalDetailCard: View {
    var icon: String
    var color: Color
    var title: String
    var value: String
    var goal: String
    var progress: Double
    var isEN: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .medium)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.1))
                    Capsule().fill(color).frame(width: geometry.size.width * min(1, max(0, progress)))
                }
            }.frame(height: 5)
                .accessibilityLabel(isEN ? "Goal progress" : "目标进度")
                .accessibilityValue("\(Int(min(1, max(0, progress)) * 100))%")
            Text((isEN ? "Goal " : "目标 ") + goal).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(padding: 12)
    }
}
