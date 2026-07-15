import SwiftUI

struct RestPopupView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("该休息了！")
                .font(.system(size: 24, weight: .bold))
            
            Text("您已经连续工作了很长时间，\n起来活动一下，喝口水休息一下眼睛吧。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("我知道了") {
                // Find and close the reminder window
                NSApp.windows.filter({ $0.title == "休息提醒" }).forEach({ $0.close() })
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 10)
        }
        .padding(40)
        .frame(width: 350, height: 280)
    }
}
