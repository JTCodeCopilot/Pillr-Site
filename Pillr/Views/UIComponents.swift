import SwiftUI

// MARK: - UI Components

struct InteractionHeaderView: View {
    let title: String
    let isPremiumMode: Bool
    let onApiKeyTap: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.pillrBackground)
            
            Spacer()
            
            if !isPremiumMode {
                Button(action: onApiKeyTap) {
                    Image(systemName: "star")
                        .font(.system(size: 16))
                        .foregroundColor(Color.pillrSecondary.opacity(0.8))
                        .padding(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct PremiumBadgeView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark")
                .foregroundColor(Color.pillrSecondary)

            Text("Premium Mode Active")
                .font(.system(size: 13))
                .foregroundColor(Color.pillrSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.12))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(hex: "#D4A017").opacity(0.12), lineWidth: 0.8)
        )
    }
}

struct PremiumLockIcon: View {
    var body: some View {
        Image(systemName: "lock")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color.pillrSecondary.opacity(0.8))
    }
}

struct InteractionSearchInputView: View {
    @Binding var drugA: String
    @Binding var drugB: String
    let isButtonDisabled: Bool
    let onSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("First Medication", text: $drugA)
                .minimalTextFieldStyle()

            TextField("Second Medication", text: $drugB)
                .minimalTextFieldStyle()
            
            Button(action: onSearch) {
                Text("Check Interaction")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.pillrBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.pillrSecondary.opacity(0.08), lineWidth: 0.8)
                    )
            }
            .disabled(isButtonDisabled)
            .opacity(isButtonDisabled ? 0.6 : 1.0)
        }
        .padding(.horizontal)
    }
}

struct APIKeyWarningView: View {
    let warningText: String
    let onEnablePremium: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color.pillrSecondary)
                
                Text("Premium Access Required")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.pillrBackground)
                
                Spacer()
            }
            
            Text(warningText)
                .font(.system(size: 13))
                .foregroundColor(Color.pillrSecondary.opacity(0.8))
            
            Button(action: onEnablePremium) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    
                    Text("Enable Premium Mode")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color.pillrPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.pillrAccent)
                .cornerRadius(8)
            }
            .padding(.top, 8)
            .buttonStyle(HapticButtonStyle(style: .soft))
        }
        .padding()
        .gyroGlassCardStyle(cornerRadius: 16, borderColor: Color(hex: "#D4A017").opacity(0.5))
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Loading States

struct LoadingView: View {
    let message: String
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.pillrBackground.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                // Animated progress circle
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.pillrBackground,
                                Color.pillrBackground.opacity(0.3)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(animationOffset))
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: animationOffset
                    )
                    .onAppear {
                        animationOffset = 360
                    }
                
                // Center dot
                Circle()
                    .fill(Color.pillrBackground)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationOffset > 180 ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                        value: animationOffset
                    )
            }
            
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.pillrBackground)
                    .multilineTextAlignment(.center)
                
                Text("Please wait...")
                    .font(.system(size: 14))
                    .foregroundColor(Color.pillrSecondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.pillrAccent)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.pillrBackground.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Error States

struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let icon: String
    
    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        icon: String = "exclamationmark.triangle.fill"
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundColor(Color.orange.opacity(0.8))
                    .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.system(size: 16))
                        .foregroundColor(Color.pillrSecondary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .lineSpacing(2)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                        Text(actionTitle)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(Color.pillrPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.pillrBackground,
                                Color(hex: "#C7A76B")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.pillrBackground.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(HapticButtonStyle(style: .medium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }
}

// MARK: - Enhanced Empty States

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let icon: String
    
    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        icon: String = "tray"
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(Color.pillrSecondary.opacity(0.6))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.system(size: 16))
                        .foregroundColor(Color.pillrSecondary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .lineSpacing(2)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.app")
                            .font(.system(size: 16, weight: .medium))
                        Text(actionTitle)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(Color.pillrPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.pillrBackground,
                                Color.pillrBackground
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(HapticButtonStyle(style: .medium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }
}

struct InteractionResultView: View {
    let interaction: DrugInteraction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interaction Results")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.pillrSecondary)
                
                Spacer()
                
                Text(interaction.severity.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color(hex: interaction.severity.color))
                    .cornerRadius(4)
            }
            
            Divider()
                .background(Color.pillrSecondary.opacity(0.05))
            
            Text(medicationCombinationText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.pillrSecondary)
            
            Text(interaction.description)
                .font(.system(size: 14))
                .foregroundColor(Color.pillrSecondary.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Recommended Action")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(interaction.recommendedAction)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.pillrSecondary.opacity(0.05))
            
            Text("Remember: This information is generated by AI and should not replace professional medical advice.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(Color.black.opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: interaction.severity.color).opacity(0.15), lineWidth: 0.8)
        )
        .padding(.horizontal)
    }
    
    private var medicationCombinationText: String {
        return "\(interaction.drugA) + \(interaction.drugB)"
    }
}

// MARK: - MinimalTextFieldStyle

private struct MinimalTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Color.black.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.pillrAccent.opacity(0.07), lineWidth: 0.8)
            )
    }
}

extension View {
    func minimalTextFieldStyle() -> some View {
        modifier(MinimalTextFieldModifier())
    }
}

// MARK: - Button Styles with Haptic Feedback

struct HapticButtonStyle: ButtonStyle {
    var style: HapticStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    switch style {
                    case .light:
                        HapticManager.shared.pulseLight()
                    case .medium:
                        HapticManager.shared.pulseMedium()
                    case .heavy:
                        HapticManager.shared.heavyImpact()
                    case .soft:
                        HapticManager.shared.pulseButton()
                    case .rigid:
                        HapticManager.shared.pulseRigid()
                    case .success:
                        HapticManager.shared.successNotification()
                    case .warning:
                        HapticManager.shared.warningNotification()
                    case .error:
                        HapticManager.shared.errorNotification()
                    case .selection:
                        HapticManager.shared.selectionChanged()
                    case .pulseLight:
                        HapticManager.shared.pulseLight()
                    case .pulseMedium:
                        HapticManager.shared.pulseMedium()
                    case .pulseRigid:
                        HapticManager.shared.pulseRigid()
                    case .pulseButton:
                        HapticManager.shared.pulseButton()
                    }
                }
            }
    }
}

// MARK: - Enhanced Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    let scaleAmount: CGFloat
    let hapticStyle: HapticStyle
    
    init(scaleAmount: CGFloat = 0.94, hapticStyle: HapticStyle = .pulseButton) {
        self.scaleAmount = scaleAmount
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    switch hapticStyle {
                    case .light:
                        HapticManager.shared.pulseLight()
                    case .medium:
                        HapticManager.shared.pulseMedium()
                    case .heavy:
                        HapticManager.shared.heavyImpact()
                    case .soft:
                        HapticManager.shared.pulseButton()
                    case .rigid:
                        HapticManager.shared.pulseRigid()
                    case .success:
                        HapticManager.shared.successNotification()
                    case .warning:
                        HapticManager.shared.warningNotification()
                    case .error:
                        HapticManager.shared.errorNotification()
                    case .selection:
                        HapticManager.shared.selectionChanged()
                    case .pulseLight:
                        HapticManager.shared.pulseLight()
                    case .pulseMedium:
                        HapticManager.shared.pulseMedium()
                    case .pulseRigid:
                        HapticManager.shared.pulseRigid()
                    case .pulseButton:
                        HapticManager.shared.pulseButton()
                    }
                }
            }
    }
}

// Stylish button with haptic feedback
struct GlassHapticButton: View {
    var title: String
    var icon: String? = nil
    var style: HapticStyle = .soft
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.black.opacity(0.12))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.pillrAccent.opacity(0.12), lineWidth: 0.8)
            )
        }
            .buttonStyle(HapticButtonStyle(style: style))
    }
}

struct NavigationActionButton: View {
    enum Variant {
        case primary
        case secondary
    }

    let title: String
    let icon: String?
    let variant: Variant
    let isDisabled: Bool
    let forceFullWidth: Bool
    let useBlurBackground: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        variant: Variant,
        isDisabled: Bool,
        forceFullWidth: Bool = false,
        useBlurBackground: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.isDisabled = isDisabled
        self.forceFullWidth = forceFullWidth
        self.useBlurBackground = useBlurBackground
        self.action = action
    }

    private var primaryGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.pillrBackground,
                Color.pillrBackground
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var secondaryBackground: Color {
        Color.black.opacity(0.25)
    }

    private var primaryForeground: Color {
        Color.pillrPrimary
    }

    private var secondaryForeground: Color {
        Color.pillrBackground
    }

    private var fillStyle: AnyShapeStyle {
        variant == .primary
            ? AnyShapeStyle(primaryGradient)
            : AnyShapeStyle(secondaryBackground)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: icon == nil ? 0 : 8) {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: variant == .primary || forceFullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, variant == .primary ? 24 : 18)
            .background(
                ZStack {
                    if useBlurBackground && variant == .secondary {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.ultraThinMaterial)
                    }

                    RoundedRectangle(cornerRadius: 22)
                        .fill(fillStyle)
                        .opacity(useBlurBackground && variant == .secondary ? 0.18 : 1)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        variant == .primary
                            ? Color.white.opacity(0.08)
                            : Color.pillrSecondary.opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
        .disabled(isDisabled)
        .foregroundColor(variant == .primary ? primaryForeground : secondaryForeground)
        .opacity(isDisabled ? 0.65 : 1)
        .buttonStyle(ScaleButtonStyle())
    }
}

// Extension to add haptic button styles to View
extension View {
    func hapticButtonStyle(_ style: HapticStyle = .soft) -> some View {
        self.buttonStyle(HapticButtonStyle(style: style))
    }
}
