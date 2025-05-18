import SwiftUI

// MARK: - UI Components

struct InteractionHeaderView: View {
    let isPremiumMode: Bool
    let onApiKeyTap: () -> Void
    
    var body: some View {
        HStack {
            Text("Medication Interactions")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Spacer()
            
            if !isPremiumMode {
                Button(action: onApiKeyTap) {
                    Image(systemName: "star")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
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
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Text("Premium Mode Active")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#C7C7BD"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.12))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.yellow.opacity(0.12), lineWidth: 0.8)
        )
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
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.08), lineWidth: 0.8)
                    )
            }
            .disabled(isButtonDisabled)
            .opacity(isButtonDisabled ? 0.6 : 1.0)
        }
        .padding(.horizontal)
    }
}

struct APIKeyWarningView: View {
    let onEnablePremium: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Text("Premium Access Required")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Spacer()
            }
            
            Text("To use the medication interaction checker, please enable Premium Mode.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            
            Button(action: onEnablePremium) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    
                    Text("Enable Premium Mode")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color(hex: "#404C42"))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.pillrAccent)
                .cornerRadius(8)
            }
            .padding(.top, 8)
            .buttonStyle(HapticButtonStyle(style: .soft))
        }
        .padding()
        .gyroGlassCardStyle(cornerRadius: 16, borderColor: Color.yellow.opacity(0.5))
        .padding(.horizontal)
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#D8B4F8").opacity(0.07), lineWidth: 0.8)
        )
        .padding(.horizontal)
    }
}

struct InteractionResultView: View {
    let interaction: DrugInteraction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interaction Results")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Spacer()
                
                Text(interaction.severity.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color(hex: interaction.severity.color))
                    .cornerRadius(4)
            }
            
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.05))
            
            Text(medicationCombinationText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Text(interaction.description)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Recommended Action")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(interaction.recommendedAction)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.05))
            
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
                    .stroke(Color(hex: "#D8B4F8").opacity(0.07), lineWidth: 0.8)
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    switch style {
                    case .light:
                        HapticManager.shared.lightImpact()
                    case .medium:
                        HapticManager.shared.mediumImpact()
                    case .heavy:
                        HapticManager.shared.heavyImpact()
                    case .soft:
                        HapticManager.shared.softImpact()
                    case .rigid:
                        HapticManager.shared.rigidImpact()
                    case .success:
                        HapticManager.shared.successNotification()
                    case .warning:
                        HapticManager.shared.warningNotification()
                    case .error:
                        HapticManager.shared.errorNotification()
                    case .selection:
                        HapticManager.shared.selectionChanged()
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
                    .stroke(Color(hex: "#D8B4F8").opacity(0.12), lineWidth: 0.8)
            )
        }
        .buttonStyle(HapticButtonStyle(style: style))
    }
}

// Extension to add haptic button styles to View
extension View {
    func hapticButtonStyle(_ style: HapticStyle = .soft) -> some View {
        self.buttonStyle(HapticButtonStyle(style: style))
    }
}
