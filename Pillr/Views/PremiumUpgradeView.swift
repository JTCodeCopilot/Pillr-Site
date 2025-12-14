import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    @State private var isButtonLoading = false
    @State private var isDisclaimerExpanded = false
    @State private var isPulseAnimating = false

    private let featureHighlights: [String] = [
        "Unlimited medications",
        "AI interaction analysis",
        "Pill count tracking",
        "Smart reminders and check ins"
    ]

    private let brandAccent = Color(hex: "#C8F365")
    private var recentUpgradeText: String {
        let calendar = Calendar.current
        let now = Date()
        let ordinal = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let hourSegment = calendar.component(.hour, from: now) / 6
        let variation = (ordinal + hourSegment) % 4
        let count = 3 + variation
        return "\(count) upgrades in the past 3 days"
    }
    private var recentUpdateMinutes: Int {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: Date())
        return 5 + (minute % 36)
    }

    var body: some View {
        ZStack {
            SettingsPalette.backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    headerSection

                    lifetimeAccessCard

                    featureConfirmationList

                    socialProofRow

                    purchaseButtonView(for: storeManager.getPremiumProduct())
                        .padding(.vertical, 12)

                    secondaryActionsSection

                    disclaimerSection

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Purchase Status", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successful") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .task {
            if !isPreview {
                await storeManager.loadProducts()
                print("User locale: \(Locale.current.identifier)")
                print("User region: \(Locale.current.regionCode ?? "Unknown")")
                print("User currency: \(Locale.current.currencyCode ?? "Unknown")")
                await storeManager.updatePurchasedProducts()
                if storeManager.isPremiumPurchased() {
                    alertMessage = "You've already purchased Premium!"
                    showingAlert = true
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Pillr Premium")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(SettingsPalette.mainText)

            Spacer()

            SettingsCloseButton {
                dismiss()
            }
        }
        .padding(.top, 12)
    }

    private var lifetimeAccessCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lifetime Premium Access")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)

                Text("Pay once. Use forever.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText.opacity(0.85))
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: "#7F867D"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 22, x: 0, y: 16)
    }

    private var socialProofRow: some View {
        HStack(spacing: 10) {
            Text(recentUpgradeText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#1F3220").opacity(0.6))
                .lineLimit(1)
                .layoutPriority(1)

            Circle()
                .fill(brandAccent)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulseAnimating ? 1.6 : 1.0)
                .opacity(isPulseAnimating ? 0.25 : 1)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulseAnimating)
                .onAppear {
                    isPulseAnimating = true
                }

            Text("Updated \(recentUpdateMinutes) minutes ago")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#1F3220").opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SettingsPalette.mainText.opacity(0.35), lineWidth: 1)
        )
    }

    private var featureConfirmationList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(featureHighlights, id: \.self) { feature in
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(brandAccent)

                    Text(feature)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(SettingsPalette.mainText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
        .padding(16)
        .settingsCardStyle(cornerRadius: 28)
    }

    @ViewBuilder
    private func purchaseButtonView(for product: Product?) -> some View {
        if let product {
            Button(action: {
                isButtonLoading = true
                purchasePremium(product: product)
            }) {
                VStack(spacing: 4) {
                    if isButtonLoading && !isPreview {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.black.opacity(0.7)))
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                    } else {
                        VStack(spacing: 4) {
                            Text("Unlock Lifetime for \(product.displayPrice)")
                                .font(.system(size: 19, weight: .heavy, design: .rounded))

                            Text("One time payment")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .opacity(0.75)
                        }
                    }
                }
                .foregroundColor(Color(hex: "#1D260D"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 23)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(brandAccent)
                )
                .shadow(color: brandAccent.opacity(0.55), radius: 24, x: 0, y: 14)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isButtonLoading && !isPreview ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isButtonLoading)
            .disabled(isButtonLoading && !isPreview)
            .accessibilityLabel("Unlock lifetime Pillr Premium for \(product.displayPrice)")
        } else {
            Button(action: {
                alertMessage = "Products are currently unavailable. Please try again later."
                showingAlert = true
            }) {
                Text("Purchase Unavailable")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#4B534A"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(hex: "#F1F3F0"))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Purchase Pillr Premium (unavailable)")
        }
    }

    private var secondaryActionsSection: some View {
        VStack(spacing: 14) {
            Button(action: { dismiss() }) {
                Text("Continue with Free Version")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText.opacity(0.5))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Continue with free version of Pillr")
            .padding(.top, 26)

            Button(action: restorePurchases) {
                Text("Restore Purchases")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText.opacity(0.6))
                    .underline(true, color: SettingsPalette.secondaryText.opacity(0.4))
                    .padding(.vertical, 4)
            }
        }
        .padding(.top, 12)
    }

    private var disclaimerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDisclaimerExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(SettingsPalette.mainText)
                        .font(.system(size: 16, weight: .semibold))

                    Text("Medical Disclaimer")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(SettingsPalette.mainText)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SettingsPalette.secondaryText)
                        .rotationEffect(.degrees(isDisclaimerExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isDisclaimerExpanded)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())

            if isDisclaimerExpanded {
                Text("This app is for tracking purposes only and should not replace professional medical advice. Always consult your healthcare provider regarding your medications.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func purchasePremium(product: Product) {
        Task {
            do {
                if let transaction = try await storeManager.purchase(product) {
                    alertMessage = "Purchase successful! All premium features are now unlocked."
                    showingAlert = true
                    OpenAIService.shared.setPremiumPurchased()
                }
                isButtonLoading = false
            } catch {
                alertMessage = "Purchase failed: \(error.localizedDescription)"
                showingAlert = true
                isButtonLoading = false
            }
        }
    }

    private func restorePurchases() {
        isButtonLoading = true
        Task {
            do {
                try await storeManager.restorePurchases()

                if storeManager.isPremiumPurchased() {
                    alertMessage = "Purchases restored successfully."
                    showingAlert = true
                    OpenAIService.shared.setPremiumPurchased()
                } else {
                    alertMessage = "No purchases found to restore."
                    showingAlert = true
                }
                isButtonLoading = false
            } catch {
                alertMessage = "Failed to restore purchases: \(error.localizedDescription)"
                showingAlert = true
                isButtonLoading = false
            }
        }
    }

}

#Preview {
    PremiumUpgradeView()
        .environmentObject(StoreManager.previewManager())
}
