import SwiftUI

struct TabBarButton: View {
    let imageName: String
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            VStack(spacing: 4) {
                // Icon with subtle animation
                Image(systemName: imageName)
                    .font(.system(size: isSelected ? 20 : 18, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.6))
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                
                // Small indicator when selected
                if isSelected {
                    Rectangle()
                        .frame(width: 25, height: 2)
                        .cornerRadius(1)
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(1))
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                } else {
                    Rectangle()
                        .frame(width: 20, height: 2)
                        .foregroundColor(.clear)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) tab")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
} 
