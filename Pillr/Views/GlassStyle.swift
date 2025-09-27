import SwiftUI

// Reusable helpers for adopting Liquid Glass with graceful fallbacks
public extension View {
    @ViewBuilder
    func glassRectBackground(cornerRadius: CGFloat = 12, isSelected: Bool = false, opacity: Double = 1.0) -> some View {
        self.background(
            Group {
                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(Color.clear)
                        .glassEffect(in: .rect(cornerRadius: cornerRadius))
                        .opacity(opacity)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 0.5)
                        )
                        .opacity(opacity)
                }
            }
        )
    }

    @ViewBuilder
    func glassCircleBackground(diameter: CGFloat, isSelected: Bool = false, opacity: Double = 1.0) -> some View {
        self.background(
            Group {
                if #available(iOS 26.0, *) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: diameter, height: diameter)
                        .glassEffect(in: .circle)
                        .opacity(opacity)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle().stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 0.5)
                        )
                        .frame(width: diameter, height: diameter)
                        .opacity(opacity)
                }
            }
        )
    }
}

// Optional container: enables merging/morphing between nearby glass elements on iOS 26+
public struct GlassContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: spacing) {
                    content
                }
            } else {
                content
            }
        }
    }
}
