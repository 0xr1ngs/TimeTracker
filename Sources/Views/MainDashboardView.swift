import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var timeManager: TimeManager
    
    var body: some View {
        TabView {
            ReviewView(timeManager: timeManager)
                .tabItem {
                    Label(timeManager.appLanguage == "en" ? "Today" : "今日", systemImage: "clock.fill")
                }
                
            FocusView(timeManager: timeManager)
                .tabItem {
                    Label(timeManager.appLanguage == "en" ? "Focus" : "专注", systemImage: "brain.head.profile")
                }
                
            if #available(macOS 13.0, *) {
                ChartsView(timeManager: timeManager)
                    .tabItem {
                        Label(timeManager.appLanguage == "en" ? "Stats" : "统计", systemImage: "chart.xyaxis.line")
                    }
            }
            
            SettingsView(timeManager: timeManager)
                .tabItem {
                    Label(timeManager.appLanguage == "en" ? "Settings" : "设置", systemImage: "gear")
                }
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
        .environment(\.locale, Locale(identifier: timeManager.appLanguage))
    }
}
