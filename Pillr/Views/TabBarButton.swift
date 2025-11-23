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

    private var isMenuIcon: Bool {
        switch imageName {
        case "line.3.horizontal",
             "line.3.horizontal.circle",
             "line.3.horizontal.decrease",
             "line.3.horizontal.decrease.circle":
            return true
        default:
            return false
        }
    }

    private var iconGradient: LinearGradient {
        if isSelected {
            if colorScheme == .light {
                let colors: [Color] = isMenuIcon
                    ? [Color.black.opacity(0.95), Color.black.opacity(0.7)]
                    : [Color.black.opacity(0.85), Color.black.opacity(0.6)]
                return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                let colors: [Color] = isMenuIcon
                    ? [Color.white.opacity(0.98), Color.white.opacity(0.82)]
                    : [Color.white.opacity(0.95), Color.white.opacity(0.75)]
                return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        } else {
            if colorScheme == .light {
                // Cool gray tint for unselected glyphs in light mode
                let baseTop = Color(red: 0.62, green: 0.68, blue: 0.74)
                let baseBottom = Color(red: 0.52, green: 0.58, blue: 0.64)
                let colors: [Color]
                if isMenuIcon {
                    colors = [baseTop.opacity(0.95), baseBottom.opacity(0.95)]
                } else {
                    colors = [baseTop.opacity(0.9), baseBottom.opacity(0.9)]
                }
                return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                return LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.strongImpact()
            action()
        }) {
            VStack(spacing: 4) {
                // Icon with subtle animation
                Image(systemName: imageName)
                    .font(.system(size: isSelected ? 20 : 18, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isMenuIcon ? AnyShapeStyle(Color(hex: "#404C42")) : AnyShapeStyle(iconGradient))
                    .shadow(color: colorScheme == .light ? Color.black.opacity(0.22) : Color.white.opacity(0.16), radius: 1.2, x: 0, y: 0)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                
                // Capsule indicator with reflective gradient and Liquid Glass effect
                if isSelected {
                    Group {
                        if #available(iOS 26.0, *) {
                            Capsule()
                                .frame(width: 28, height: 3)
                                .glassEffect(in: .capsule)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.35),
                                                    Color.white.opacity(0.15),
                                                    Color.white.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.7
                                        )
                                )
                        } else {
                            Capsule()
                                .frame(width: 28, height: 3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.65)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                        }
                    }
                    .shadow(color: Color.white.opacity(0.18), radius: 4, x: 0, y: 0)
                    .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                } else {
                    Capsule()
                        .frame(width: 20, height: 2)
                        .foregroundColor(.clear)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Rectangle()
                            .fill(Color.clear)
                            .glassEffect(in: .rect(cornerRadius: 12))
                            .opacity(isSelected ? 1.0 : 0.9)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.35),
                                                Color.white.opacity(0.08),
                                                Color.white.opacity(0.25)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 1 : 0.7
                                    )
                                    .blendMode(.plusLighter)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.28),
                                                Color.white.opacity(0.08),
                                                Color.white.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 1 : 0.7
                                    )
                                    .blendMode(.plusLighter)
                            )
                            .opacity(isSelected ? 1.0 : 0.9)
                    }
                }
            )
            .shadow(color: Color.white.opacity(isSelected ? 0.22 : 0.08), radius: isSelected ? 10 : 6, x: 0, y: isSelected ? 4 : 2)
            .hoverEffect(.lift)
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
