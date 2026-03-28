import SwiftUI

enum SettingsMetrics {
    static let cardCornerRadius: CGFloat = 26
    static let rowSpacing: CGFloat = 14
    static let rowIconSize: CGFloat = 18
    static let rowIconFrame: CGFloat = 28
    static let arrowSize: CGFloat = 12
    static let arrowOpacity: Double = 0.7
}

enum SettingsPalette {
    static let backgroundColor = Color.pillrPrimary
    static let headerColor = Color.pillrBackground
    static let secondaryText = Color.pillrSecondary.opacity(0.78)
    static let mainText = Color.pillrBackground
    static let cardBackground = Color.white.opacity(0.04)
    static let nestedCardBackground = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.06)
    static let arrowColor = Color.pillrSecondary
    static let closeStroke = Color.pillrBackground.opacity(0.45)
    static let toggleActive = Color.pillrToggleActive
}

struct SettingsCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .stroke(SettingsPalette.closeStroke, lineWidth: 1)
                    .frame(width: 36, height: 36)

                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SettingsPalette.mainText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension View {
    func settingsCardStyle(cornerRadius: CGFloat = SettingsMetrics.cardCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(SettingsPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(SettingsPalette.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
            .shadow(color: Color.white.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
