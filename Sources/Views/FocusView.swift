import SwiftUI

struct FocusView: View {
    @ObservedObject var timeManager: TimeManager
    @State private var selectedMinutes: Int = 25
    
    let presets = [15, 25, 45, 60]
    
    private var isEN: Bool { timeManager.appLanguage == "en" }
    
    // Clean System Blue theme to match the rest of the app's colors
    let themeColor = Color.blue
    
    var body: some View {
        VStack(spacing: 6) {
            // Header (Completely compact to prevent any overflow)
            HStack {
                Text(isEN ? "Focus Timer ⏱️" : "番茄专注 ⏱️")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 2)
            
            if timeManager.isFocusModeActive {
                // Focus Active Screen
                VStack(spacing: 12) {
                    Spacer(minLength: 2)
                    ZStack {
                        // Dial ticks
                        ForEach(0..<60) { tick in
                            Rectangle()
                                .fill(tick % 5 == 0 ? themeColor.opacity(0.4) : themeColor.opacity(0.12))
                                .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 6 : 3)
                                .offset(y: -70)
                                .rotationEffect(.degrees(Double(tick) * 6))
                        }
                        
                        Circle()
                            .fill(themeColor.opacity(0.04))
                            .frame(width: 140, height: 140)
                        
                        Circle()
                            .stroke(themeColor.opacity(0.08), lineWidth: 6)
                            .frame(width: 130, height: 130)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(timeManager.focusTimeRemaining / (Double(selectedMinutes) * 60)))
                            .stroke(
                                themeColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: timeManager.focusTimeRemaining)
                        
                        // Active Text Info
                        VStack(spacing: 2) {
                            Text("🐻💤")
                                .font(.system(size: 20))
                            Text(formatCountdown(timeManager.focusTimeRemaining))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text(isEN ? "Focusing" : "专注中")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 160, height: 160)
                    
                    Spacer(minLength: 2)
                    
                    Button(action: {
                        timeManager.stopFocusMode()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill").font(.caption)
                            Text(isEN ? "Stop Focus Session" : "放弃此次专注")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.pink.gradient)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 2)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Focus Idle Screen: Apple Watch Rotary Circular Slider Dial
                VStack(spacing: 12) {
                    Spacer(minLength: 2)
                    
                    ZStack {
                        // Chronograph ticks
                        ForEach(0..<60) { tick in
                            Rectangle()
                                .fill(tick % 5 == 0 ? Color.primary.opacity(0.2) : Color.primary.opacity(0.06))
                                .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 6 : 3)
                                .offset(y: -70)
                                .rotationEffect(.degrees(Double(tick) * 6))
                        }
                        
                        // Solid guide ring
                        Circle()
                            .stroke(themeColor.opacity(0.08), lineWidth: 8)
                            .frame(width: 130, height: 130)
                        
                        // Idle Progress Ring (1 full rotation = exactly 60 minutes)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(Double(selectedMinutes) / 60.0, 1.0)))
                            .stroke(
                                themeColor.opacity(0.7),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: selectedMinutes)
                        
                        // Fully transparent overlay covering the entire area to capture Drag gestures smoothly
                        Circle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: 140, height: 140)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let center = CGPoint(x: 70, y: 70)
                                        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                                        let angle = atan2(vector.dy, vector.dx)
                                        var degrees = angle * 180 / .pi
                                        if degrees < 0 { degrees += 360 }
                                        // Offset 90 degrees to align 12 o'clock as start point
                                        degrees = (degrees + 90).truncatingRemainder(dividingBy: 360)
                                        
                                        // 360 degrees maps directly to 5...60 minutes (making dragging follow mouse perfectly!)
                                        let rawMins = Int(degrees / 360 * 55) + 5
                                        let clampedMins = max(5, min(60, rawMins))
                                        selectedMinutes = (clampedMins / 5) * 5
                                    }
                            )
                        
                        // Center Display Info
                        VStack(spacing: 2) {
                            Text("🦊")
                                .font(.system(size: 24))
                            Text("\(selectedMinutes)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .monospacedDigit()
                            Text(isEN ? "Mins" : "分钟")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 160, height: 160)
                    
                    Text(isEN ? "🎡 Drag along the circle to select minutes" : "🎡 拖拽圆环可自由调整时间")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, -2)
                    
                    Spacer(minLength: 2)
                    
                    // Quick presets row
                    HStack(spacing: 12) {
                        ForEach(presets, id: \.self) { preset in
                            Button(action: {
                                selectedMinutes = preset
                            }) {
                                Text("\(preset)m")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedMinutes == preset ? .white : .primary)
                                    .frame(width: 44, height: 26)
                                    .background(selectedMinutes == preset ? themeColor.gradient : Color.primary.opacity(0.06).gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 2)
                    
                    // Start Button
                    Button(action: {
                        timeManager.startFocusMode(minutes: selectedMinutes)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.caption)
                            Text(isEN ? "Begin Focus" : "开始专注旅行")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 10)
                        .background(themeColor.gradient)
                        .clipShape(Capsule())
                        .shadow(color: themeColor.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 2)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }
    
    func formatCountdown(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
