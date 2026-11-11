import SwiftUI

extension View {
    func dashboardCard(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.025), radius: 8, y: 3)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    var color: Color = .blue
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(color.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.4),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
