import SwiftUI

enum OnboardingTarget: Hashable {
    case addMedicationButton
    case historyTab
    case focusTimeline
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case addMedication
    case historyTab
    case focusTimeline

    var id: Int { rawValue }

    var target: OnboardingTarget {
        switch self {
        case .addMedication:
            return .addMedicationButton
        case .historyTab:
            return .historyTab
        case .focusTimeline:
            return .focusTimeline
        }
    }

    var title: String {
        switch self {
        case .addMedication:
            return "Add your first medication"
        case .historyTab:
            return "Review your history"
        case .focusTimeline:
            return "Track your focus timeline"
        }
    }

    var message: String {
        switch self {
        case .addMedication:
            return "Tap the plus button any time you need to add another medication or supplement."
        case .historyTab:
            return "The History tab shows everything you’ve logged so you can keep a trustworthy audit trail."
        case .focusTimeline:
            return "The focus timeline maps each stimulant dose so you can understand when you’ll be most alert."
        }
    }

    var primaryButtonTitle: String {
        self == .focusTimeline ? "Get started" : "Next"
    }

    var highlightPadding: CGFloat {
        switch self {
        case .addMedication:
            return 6
        case .historyTab:
            return 6
        case .focusTimeline:
            return 10
        }
    }

    var highlightSizeOverride: CGSize? {
        switch self {
        case .addMedication:
            return CGSize(width: 52, height: 52)
        case .historyTab:
            return CGSize(width: 54, height: 54)
        default:
            return nil
        }
    }

    var highlightOffset: CGSize { .zero }

    var highlightCornerStyle: HighlightCornerStyle {
        switch self {
        case .addMedication, .historyTab:
            return .circular
        case .focusTimeline:
            return .radius(26)
        }
    }
}

enum HighlightCornerStyle {
    case circular
    case radius(CGFloat)
}

struct OnboardingGuideOverlay: View {
    let step: OnboardingStep
    let geometry: GeometryProxy
    let highlightFrame: CGRect?
    let stepIndex: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private var paddedHighlightRect: CGRect? {
        guard let highlightFrame else { return nil }

        var rect = highlightFrame
        if let override = step.highlightSizeOverride {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            rect = CGRect(
                x: center.x - override.width / 2,
                y: center.y - override.height / 2,
                width: override.width,
                height: override.height
            )
        }

        rect = rect.offsetBy(dx: step.highlightOffset.width, dy: step.highlightOffset.height)
        return rect.insetBy(dx: -step.highlightPadding, dy: -step.highlightPadding)
    }

    private func cornerRadius(for rect: CGRect) -> CGFloat {
        switch step.highlightCornerStyle {
        case .circular:
            return min(rect.width, rect.height) / 2
        case .radius(let value):
            return value
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .overlay(
                    Group {
                        if let rect = paddedHighlightRect {
                            RoundedRectangle(cornerRadius: cornerRadius(for: rect), style: .continuous)
                                .fill(Color.black)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .blendMode(.destinationOut)
                        }
                    }
                )
                .compositingGroup()

            if let rect = paddedHighlightRect {
                RoundedRectangle(cornerRadius: cornerRadius(for: rect), style: .continuous)
                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                    .shadow(color: Color.white.opacity(0.25), radius: 12, x: 0, y: 6)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: rect)
            }

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Step \(stepIndex) of \(totalSteps)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.75))

                    Text(step.title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(step.message)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button(action: onSkip) {
                            Text("Skip tour")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                        }

                        Spacer()

                        Button(action: onNext) {
                            Text(step.primaryButtonTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#2F352F"))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "#C8F365"))
                                .cornerRadius(14)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.black.opacity(0.35))
                                .blur(radius: 30)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 28)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title). \(step.message)")
    }
}

private struct OnboardingTargetModifier: ViewModifier {
    let target: OnboardingTarget

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    let hasArea = frame.width > 1 && frame.height > 1
                    Color.clear
                        .preference(
                            key: OnboardingHighlightPreferenceKey.self,
                            value: hasArea ? [target: frame] : [:]
                        )
                }
            )
    }
}

extension View {
    func onboardingTarget(_ target: OnboardingTarget) -> some View {
        modifier(OnboardingTargetModifier(target: target))
    }

    @ViewBuilder
    func onboardingTarget(_ target: OnboardingTarget, enabled: Bool) -> some View {
        if enabled {
            modifier(OnboardingTargetModifier(target: target))
        } else {
            self
        }
    }
}

struct OnboardingHighlightPreferenceKey: PreferenceKey {
    static var defaultValue: [OnboardingTarget: CGRect] = [:]

    static func reduce(value: inout [OnboardingTarget: CGRect], nextValue: () -> [OnboardingTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
