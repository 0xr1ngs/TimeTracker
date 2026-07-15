import SwiftUI

struct ReviewView: View {
    @ObservedObject var timeManager: TimeManager
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var isEN: Bool { timeManager.appLanguage == "en" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Header with interactive state switch
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isEN ? "Today's Status 💻" : "今日状态 💻")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(isEN ? "Track automatically via screen unlocking or toggle manually" : "解锁屏幕自动记录，或在此手动切换状态")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Toggle button
                Button(action: {
                    timeManager.toggleWorkStatus()
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(timeManager.isWorking ? Color.blue : Color.green)
                            .frame(width: 8, height: 8)
                            .shadow(color: (timeManager.isWorking ? Color.blue : Color.green).opacity(0.4), radius: 3)
                        
                        Text(timeManager.isWorking ? 
                             (isEN ? "💻 Working (Toggle)" : "💻 工作中 (点击切换)") : 
                             (isEN ? "☕️ Resting (Toggle)" : "☕️ 休息中 (点击切换)")
                        )
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Spacer(minLength: 12)
            
            // Rings & Timeline
            HStack(spacing: 20) {
                // Rings
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.08), lineWidth: 12)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(timeManager.totalWorkTimeToday / (timeManager.workGoalHours * 3600), 1.0)))
                        .stroke(
                            AngularGradient(colors: [.blue.opacity(0.7), .blue, .blue.opacity(0.9)], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: timeManager.totalWorkTimeToday)
                    
                    Circle()
                        .stroke(Color.green.opacity(0.08), lineWidth: 12)
                        .padding(18)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(timeManager.totalRestTimeToday / (timeManager.restGoalMinutes * 60), 1.0)))
                        .stroke(
                            AngularGradient(colors: [.green.opacity(0.7), .green, .green.opacity(0.9)], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: timeManager.totalRestTimeToday)
                        .padding(18)
                    
                    Circle()
                        .stroke(Color.purple.opacity(0.08), lineWidth: 12)
                        .padding(36)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(Double(timeManager.focusSessionsCompletedToday) / Double(max(timeManager.focusGoalSessions, 1)), 1.0)))
                        .stroke(
                            AngularGradient(colors: [.purple.opacity(0.7), .purple, .purple.opacity(0.9)], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: timeManager.focusSessionsCompletedToday)
                        .padding(36)
                    
                    Text(timeManager.isWorking ? "🌱" : "🧸")
                        .font(.system(size: 28))
                }
                .frame(width: 140, height: 140)
                
                // Timeline
                VStack(alignment: .leading, spacing: 10) {
                    Text(isEN ? "Timeline Split 🌓" : "时段占比 🌓")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(isEN ? "☀️ Morning (Before 12:00)" : "☀️ 上午 (12:00前)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTimeShort(timeManager.workAMToday + timeManager.restAMToday))
                                .font(.system(size: 11, weight: .bold))
                        }
                        
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                let total = max(timeManager.workAMToday + timeManager.restAMToday, 1)
                                let workRatio = CGFloat(timeManager.workAMToday / total)
                                let restRatio = CGFloat(timeManager.restAMToday / total)
                                
                                if timeManager.workAMToday > 0 {
                                    Color.blue
                                        .frame(width: geo.size.width * workRatio)
                                }
                                if timeManager.restAMToday > 0 {
                                    Color.green
                                        .frame(width: geo.size.width * restRatio)
                                }
                                if timeManager.workAMToday == 0 && timeManager.restAMToday == 0 {
                                    Color.primary.opacity(0.06)
                                }
                            }
                        }
                        .frame(height: 6)
                        .clipShape(Capsule())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(isEN ? "🌙 Afternoon (After 12:00)" : "🌙 下午 (12:00后)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTimeShort(timeManager.workPMToday + timeManager.restPMToday))
                                .font(.system(size: 11, weight: .bold))
                        }
                        
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                let total = max(timeManager.workPMToday + timeManager.restPMToday, 1)
                                let workRatio = CGFloat(timeManager.workPMToday / total)
                                let restRatio = CGFloat(timeManager.restPMToday / total)
                                
                                if timeManager.workPMToday > 0 {
                                    Color.blue
                                        .frame(width: geo.size.width * workRatio)
                                }
                                if timeManager.restPMToday > 0 {
                                    Color.green
                                        .frame(width: geo.size.width * restRatio)
                                }
                                if timeManager.workPMToday == 0 && timeManager.restPMToday == 0 {
                                    Color.primary.opacity(0.06)
                                }
                            }
                        }
                        .frame(height: 6)
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(VisualEffectBlur(material: .popover, blendingMode: .withinWindow))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            
            Spacer(minLength: 12)
            
            // Goals Detail Cards (Stands naturally, pushed and balanced by middle Spacers)
            HStack(spacing: 12) {
                GoalDetailCard(
                    icon: "laptopcomputer",
                    color: .blue,
                    title: isEN ? "Work Time" : "工作时间",
                    value: formatTime(timeManager.totalWorkTimeToday),
                    goal: formatGoal(timeManager.workGoalHours, unit: "h"),
                    isEN: isEN
                )
                GoalDetailCard(
                    icon: "cup.and.saucer.fill",
                    color: .green,
                    title: isEN ? "Rest Time" : "休息时间",
                    value: formatTime(timeManager.totalRestTimeToday),
                    goal: formatGoal(timeManager.restGoalMinutes, unit: "m"),
                    isEN: isEN
                )
                GoalDetailCard(
                    icon: "brain.head.profile",
                    color: .purple,
                    title: isEN ? "Focus Pomos" : "专注番茄",
                    value: isEN ? "\(timeManager.focusSessionsCompletedToday)x" : "\(timeManager.focusSessionsCompletedToday)次",
                    goal: isEN ? "\(timeManager.focusGoalSessions)x" : "\(timeManager.focusGoalSessions)次",
                    isEN: isEN
                )
            }
            
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .onReceive(timer) { _ in
            timeManager.updateStatusText()
        }
    }
    
    // Reformatted to consistently use spaces (e.g. 4h 20m)
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return isEN ? "\(minutes)m" : "\(minutes)分钟"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    
    func formatTimeShort(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    
    func formatGoal(_ val: Double, unit: String) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(val))\(unit)"
        }
        return String(format: "%.1f%@", val, unit)
    }
}

struct GoalDetailCard: View {
    var icon: String
    var color: Color
    var title: String
    var value: String
    var goal: String
    var isEN: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            Text((isEN ? "Goal: " : "目标: ") + goal)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(12) // Slightly larger padding to match larger text
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(VisualEffectBlur(material: .popover, blendingMode: .withinWindow))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
}
