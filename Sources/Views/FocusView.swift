import SwiftUI

struct FocusView: View {
    @ObservedObject var timeManager: TimeManager
    @State private var selectedMinutes = 25
    private var isEN: Bool { timeManager.appLanguage == "en" }
    private var active: Bool { timeManager.isFocusModeActive }
    private var progress: Double { active ? timeManager.focusProgress : Double(selectedMinutes) / 60 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isEN ? "One thing at a time" : "一次，只专注一件事")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(isEN ? "Choose your time. Find your flow." : "选一段时间，把注意力交给当下。")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 20) {
                    ZStack {
                        ForEach(0..<60) { tick in
                            Capsule().fill(Color.primary.opacity(tick % 5 == 0 ? 0.25 : 0.09))
                                .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 9 : 4)
                                .offset(y: -111).rotationEffect(.degrees(Double(tick) * 6))
                        }
                        Circle().stroke(Color.blue.opacity(0.08), lineWidth: 11).frame(width: 198, height: 198)
                        Circle().trim(from: 0, to: min(1, max(0, progress)))
                            .stroke(Color.blue.gradient, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                            .frame(width: 198, height: 198).rotationEffect(.degrees(-90))
                        if !active {
                            Circle().fill(.clear).contentShape(Circle()).frame(width: 230, height: 230)
                                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                    let angle = atan2(value.location.y - 115, value.location.x - 115) * 180 / .pi
                                    let degrees = (angle + 450).truncatingRemainder(dividingBy: 360)
                                    selectedMinutes = max(5, min(60, Int((degrees / 360 * 12).rounded()) * 5))
                                })
                                .accessibilityLabel(isEN ? "Focus duration" : "专注时长")
                                .accessibilityValue("\(selectedMinutes)")
                                .accessibilityAdjustableAction { direction in
                                    switch direction {
                                    case .increment: selectedMinutes = min(60, selectedMinutes + 5)
                                    case .decrement: selectedMinutes = max(5, selectedMinutes - 5)
                                    @unknown default: break
                                    }
                                }
                        }
                        VStack(spacing: 8) {
                            Image(systemName: active ? "brain.head.profile" : "timer").foregroundColor(.blue)
                                .font(.system(size: 22, weight: .medium))
                            Text(active ? countdown(timeManager.focusTimeRemaining) : "\(selectedMinutes)")
                                .font(.system(size: active ? 38 : 54, weight: .medium, design: .rounded)).monospacedDigit()
                            Text(active ? (isEN ? "Stay with your focus" : "保持专注，慢慢来") : (isEN ? "MINUTES" : "分钟"))
                                .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        }.allowsHitTesting(false)
                    }
                    .frame(width: 240, height: 240)
                    .scaleEffect(0.85).frame(width: 204, height: 204).padding(.top, 4)

                    if !active {
                        HStack(spacing: 10) {
                            ForEach([15, 25, 45, 60], id: \.self) { minutes in
                                Button { selectedMinutes = minutes } label: {
                                    Text("\(minutes) min").font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .foregroundColor(selectedMinutes == minutes ? .blue : .secondary)
                                        .background(selectedMinutes == minutes ? Color.blue.opacity(0.1) : Color.primary.opacity(0.035), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                        Text(isEN ? "Drag the dial, or choose a preset." : "拖动圆环，或选择一个常用时长。")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Button {
                        if active { timeManager.stopFocusMode() }
                        else { timeManager.startFocusMode(minutes: selectedMinutes) }
                    } label: {
                        Label(active ? (isEN ? "End focus" : "结束此次专注") : (isEN ? "Begin focus" : "开始专注"), systemImage: active ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold)).frame(width: 210).padding(.vertical, 5)
                    }
                    .buttonStyle(PrimaryActionStyle(color: active ? .pink : .blue))
                }
                .frame(maxWidth: .infinity).dashboardCard(padding: 20)
                Label(isEN ? "Rest reminders keep running during focus." : "专注期间，休息提醒仍会按时照顾你。", systemImage: "leaf")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 24)
        }
    }

    private func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
