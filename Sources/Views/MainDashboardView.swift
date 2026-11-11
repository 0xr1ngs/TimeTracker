import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var timeManager: TimeManager
    @State private var selectedTab = 0
    private var isEN: Bool { timeManager.appLanguage == "en" }
    init(timeManager: TimeManager, initialTab: Int = 0) {
        self.timeManager = timeManager
        _selectedTab = State(initialValue: initialTab)
    }

    private let symbols = ["square.grid.2x2", "timer", "chart.bar.xaxis", "slider.horizontal.3"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 20, weight: .medium)).foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TimeTracker").font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(isEN ? "Make room for a better rhythm" : "找到工作与休息的好节奏")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(timeManager.isLunchBreakExempt ? Color.secondary : (timeManager.isWorking ? Color.blue : Color.green)).frame(width: 6, height: 6)
                    Text(timeManager.isLunchBreakExempt ? (isEN ? "Lunch" : "午休中") : (timeManager.isWorking ? (isEN ? "Working" : "工作中") : (isEN ? "Resting" : "休息中")))
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.primary.opacity(0.04), in: Capsule())
            }
            .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16)

            HStack(spacing: 5) {
                ForEach(0..<4) { index in
                    Button { selectedTab = index } label: {
                        Label((isEN ? ["Today", "Focus", "Insights", "Settings"] : ["今日", "专注", "统计", "设置"])[index], systemImage: symbols[index])
                            .font(.system(size: 13, weight: selectedTab == index ? .semibold : .medium))
                            .foregroundColor(selectedTab == index ? .blue : .secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selectedTab == index ? Color(nsColor: .controlBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
                }
            }
            .padding(4).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24).padding(.bottom, 14)

            Group {
                switch selectedTab {
                case 0: ReviewView(timeManager: timeManager)
                case 1: FocusView(timeManager: timeManager)
                case 2: ChartsView(timeManager: timeManager)
                default: SettingsView(timeManager: timeManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 600, minHeight: 580)
        .environment(\.locale, Locale(identifier: timeManager.appLanguage))
    }
}
