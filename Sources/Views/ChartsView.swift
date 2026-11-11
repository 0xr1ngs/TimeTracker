import SwiftUI
import Charts
import AppKit

struct ChartItem: Identifiable {
    let id = UUID()
    let date: String
    let hours: Double
    let type: String // "工作" or "休息"
    let isWeekend: Bool
}

@available(macOS 13.0, *)
struct ChartsView: View {
    @ObservedObject var timeManager: TimeManager
    @State private var weeklyRecords: [DailyRecord] = []
    @State private var chartItems: [ChartItem] = []
    
    private var isEN: Bool { timeManager.appLanguage == "en" }
    
    // Derived stats
    private var totalWorkThisWeek: TimeInterval {
        weeklyRecords.reduce(0) { $0 + $1.totalWorkTime }
    }
    
    private var totalRestThisWeek: TimeInterval {
        weeklyRecords.reduce(0) { $0 + $1.totalRestTime }
    }
    
    private var totalFocusThisWeek: TimeInterval {
        weeklyRecords.reduce(0) { $0 + ($1.totalFocusTime ?? 0) }
    }
    
    // Days goal reached
    private var restGoalMetDays: Int {
        weeklyRecords.filter { $0.totalRestTime >= timeManager.restGoalMinutes * 60 }.count
    }
    
    private var workGoalMetDays: Int {
        weeklyRecords.filter { $0.totalWorkTime >= timeManager.workGoalHours * 3600 }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text(isEN ? "Weekly summary" : "把一周的努力，看得更清楚")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(isEN ? "Time allocation trends over the last 7 days" : "过去 7 天内时间分配的演进趋势")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Summary Widgets with Enlarged Fonts
            HStack(spacing: 12) {
                SummaryMiniCard(title: isEN ? "Total Work" : "累计工作", value: formatHours(totalWorkThisWeek), color: .blue, icon: "laptopcomputer")
                SummaryMiniCard(title: isEN ? "Total Rest" : "累计休息", value: formatHours(totalRestThisWeek), color: .green, icon: "cup.and.saucer.fill")
                SummaryMiniCard(title: isEN ? "Total Focus" : "累计专注", value: formatHours(totalFocusThisWeek), color: .purple, icon: "brain.head.profile")
            }
            
            // Goal Achievement Dashboard Card (Playful/Cute details, not raw KPI check)
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("🛌")
                    Text(isEN ? "Rest Goal Met:" : "休息目标达标:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(isEN ? "\(restGoalMetDays) / 7 Days" : "\(restGoalMetDays) / 7 天")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08))
                .clipShape(Capsule())
                
                HStack(spacing: 6) {
                    Text("💻")
                    Text(isEN ? "Work Goal Met:" : "工作目标达标:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(isEN ? "\(workGoalMetDays) / 7 Days" : "\(workGoalMetDays) / 7 天")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08))
                .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.top, 2)
            
            // Chart Container
            VStack(alignment: .leading, spacing: 12) {
                Chart(chartItems) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Hours", item.hours),
                        width: .fixed(12)
                    )
                    .foregroundStyle(
                        item.isWeekend ? 
                        (item.type == "工作" ? Color.orange.gradient : Color.yellow.gradient) :
                        (item.type == "工作" ? Color.blue.gradient : Color.green.gradient)
                    )
                    .position(by: .value("Type", item.type))
                    // Display specific times directly on top of each bar!
                    .annotation(position: .top) {
                        if item.hours > 0 {
                            Text(String(format: "%.1fh", item.hours))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartLegend(.hidden)
                .frame(maxHeight: .infinity)
                .overlay {
                    if chartItems.allSatisfy({ $0.hours == 0 }) {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.bar.xaxis").font(.system(size: 30)).foregroundColor(.blue.opacity(0.7))
                            Text(isEN ? "Your week starts here" : "每一段投入，都会被记住")
                                .font(.system(size: 15, weight: .semibold))
                            Text(isEN ? "Your work and breaks will appear as you use TimeTracker." : "开始记录工作与休息后，这里会显示你的每周节奏。")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        .padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                // Legend (covering all 4 colors displayed in chart)
                HStack(spacing: 12) {
                    LegendItem(color: .blue, label: isEN ? "Work (Wkdy)" : "工作 (周中)")
                    LegendItem(color: .green, label: isEN ? "Rest (Wkdy)" : "休息 (周中)")
                    LegendItem(color: .orange, label: isEN ? "Work (Wkend)" : "工作 (周末)")
                    LegendItem(color: .yellow, label: isEN ? "Rest (Wkend)" : "休息 (周末)")
                    Spacer()
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dashboardCard()

        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .onAppear {
            let records = timeManager.getRecordsForLast(days: 7)
            self.weeklyRecords = records
            
            self.chartItems = records.flatMap { record in
                let isWeekend = checkIsWeekend(record.dateString)
                return [
                    ChartItem(date: formatShortDate(record.dateString), hours: record.totalWorkTime / 3600.0, type: "工作", isWeekend: isWeekend),
                    ChartItem(date: record.dateString == "" ? "" : formatShortDate(record.dateString), hours: record.totalRestTime / 3600.0, type: "休息", isWeekend: isWeekend)
                ]
            }
        }
    }
    
    func checkIsWeekend(_ dateStr: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else {
            return false
        }
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    func formatShortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[1])/\(parts[2])"
        }
        return dateStr
    }
    
    func formatHours(_ interval: TimeInterval) -> String {
        let hours = interval / 3600.0
        if hours == 0 {
            return "0.0h"
        }
        return String(format: "%.1fh", hours)
    }
}

@available(macOS 13.0, *)
struct SummaryMiniCard: View {
    var title: String
    var value: String
    var color: Color
    var icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13)) // Enlarged
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 11, weight: .bold)) // Enlarged to 11
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded)) // Enlarged to 18
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .dashboardCard(padding: 14)
    }
}

struct LegendItem: View {
    var color: Color
    var label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}
