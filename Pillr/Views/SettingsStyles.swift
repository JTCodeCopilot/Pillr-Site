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
    static let backgroundColor = Color(hex: "#404C42")
    static let headerColor = Color(hex: "#E0E7DC").opacity(0.85)
    static let secondaryText = Color(hex: "#E0E7DC").opacity(0.78)
    static let mainText = Color(hex: "#F5F7F4")
    static let cardBackground = Color(hex: "#4E5B52")
    static let nestedCardBackground = Color(hex: "#3E4A3F").opacity(0.85)
    static let cardStroke = Color.white.opacity(0.08)
    static let arrowColor = Color(hex: "#E0E7DC")
    static let closeStroke = Color(hex: "#F5F7F4").opacity(0.45)
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
