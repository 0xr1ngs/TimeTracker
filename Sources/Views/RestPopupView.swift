import SwiftUI

struct RestPopupView: View {
    @ObservedObject var timeManager: TimeManager
    private var isEN: Bool { timeManager.appLanguage == "en" }
    private var minutes: Int { timeManager.isReminderPreview ? 60 : Int(timeManager.currentSessionElapsed / 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 54, height: 54)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEN ? "TIME TO RECHARGE" : "给身体充个电")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    Text(isEN ? "A little break goes a long way." : "认真工作，也要好好休息。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if timeManager.isReminderPreview {
                    Text(isEN ? "Preview" : "预览")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(minutes)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(isEN ? "minutes of continuous work" : "分钟连续工作")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isEN ? "Stand up. Look away. Breathe." : "现在，离开屏幕一小会儿。")
                    .font(.system(size: 21, weight: .semibold))
                Text(isEN ? "Stretch your shoulders, get some water and give your eyes a rest." : "起身走走、喝点水，让肩颈和眼睛都放松一下。")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            if timeManager.isReminderPreview {
                Button(isEN ? "Close preview" : "关闭预览") { timeManager.hideRestReminder() }
                    .buttonStyle(PrimaryActionStyle(color: .orange))
            } else {
                HStack(spacing: 12) {
                    Button { timeManager.beginRest() } label: {
                        Label(isEN ? "Start break" : "开始休息", systemImage: "cup.and.saucer.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionStyle(color: .orange))
                    Button(isEN ? "Remind in 10 min" : "10 分钟后提醒") { timeManager.snoozeRestReminder() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(28)
        .frame(width: 460, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.8))
                .frame(width: 68, height: 4).padding(.top, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
