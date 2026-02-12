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
    private static var palette: AppThemePalette { AppTheme.shared.palette }

    static var backgroundColor: Color { palette.backgroundPrimaryColor }
    static var headerColor: Color { palette.textSecondaryColor.opacity(0.88) }
    static var secondaryText: Color { palette.textSecondaryColor.opacity(0.78) }
    static var mainText: Color { palette.textPrimaryColor }
    static var cardBackground: Color { palette.surfacePrimaryColor.opacity(0.42) }
    static var nestedCardBackground: Color { palette.surfaceSecondaryColor.opacity(0.5) }
    static var cardStroke: Color { palette.borderColor.opacity(0.38) }
    static var arrowColor: Color { palette.iconSecondaryColor }
    static var closeStroke: Color { palette.borderColor.opacity(0.65) }
    static var toggleActive: Color { palette.buttonSecondaryBackgroundColor }
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
            .shadow(color: Color.black.opacity(AppTheme.shared.mode == .dark ? 0.28 : 0.2), radius: 10, x: 0, y: 6)
            .shadow(color: SettingsPalette.mainText.opacity(AppTheme.shared.mode == .dark ? 0.03 : 0.06), radius: 2, x: 0, y: 1)
    }
}
