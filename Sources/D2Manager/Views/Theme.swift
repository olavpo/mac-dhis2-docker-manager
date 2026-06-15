import SwiftUI

/// Visual language: status-as-color over Liquid Glass, SF Rounded for identity.
enum Theme {
    static func color(_ status: InstanceStatus) -> Color {
        switch status {
        case .running: return Color(red: 0.19, green: 0.82, blue: 0.35)   // #30D158
        case .partial: return Color(red: 1.00, green: 0.62, blue: 0.04)   // #FF9F0A
        case .stopped: return Color(red: 0.56, green: 0.56, blue: 0.58)   // #8E8E93
        }
    }

    /// DHIS2-blue accent for primary actions.
    static let accent = Color(red: 0.08, green: 0.49, blue: 0.84)         // #147CD7

    static let title = Font.system(.headline, design: .rounded).weight(.semibold)
    static let rowName = Font.system(.body, design: .rounded).weight(.medium)
}

/// A status indicator that "breathes" — running instances emit a slow expanding
/// ring; stopped/partial show a calm solid dot. Respects Reduce Motion.
struct StatusDot: View {
    let status: InstanceStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        let color = Theme.color(status)
        ZStack {
            if status == .running && !reduceMotion {
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 0.6)
            }
            Circle()
                .fill(color)
                .shadow(color: color.opacity(status == .running ? 0.8 : 0), radius: 3)
        }
        .frame(width: 9, height: 9)
        .onAppear(perform: animate)
        .onChange(of: status) { animate() }
    }

    private func animate() {
        pulse = false
        guard status == .running, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}
