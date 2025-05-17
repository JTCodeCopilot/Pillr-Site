import SwiftUI

struct TabBarButton: View {
    let imageName: String
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Simplified icon
                Image(systemName: imageName)
                    .font(.system(size: 18, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.6))
                
                // Minimal text - only show if selected
                if isSelected {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(isSelected ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.6))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) tab")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
        .buttonStyle(HapticButtonStyle(style: .soft))
    }
} 