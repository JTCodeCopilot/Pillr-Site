import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var hasTriedFeatures = false
    @State private var isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    @State private var isButtonLoading = false

    private let premiumFeatures: [PremiumFeatureContent] = [
        PremiumFeatureContent(
            icon: "pills.fill",
            title: "Unlimited Medications",
            description: "Track unlimited medications with twice and three time daily reminders."
        ),
        PremiumFeatureContent(
            icon: "icloud",
            title: "iCloud Sync & Backup",
            description: "Mirror data through iCloud for seamless recovery"
        ),
        PremiumFeatureContent(
            icon: "hourglass",
            title: "AI Interaction Analysis",
            description: "Instantly review potential medication conflicts"
        ),
        PremiumFeatureContent(
            icon: "number.circle.fill",
            title: "Pill Count Tracking",
            description: "Inventory dashboards with refill warnings"
        ),
        PremiumFeatureContent(
            icon: "arrow.clockwise.circle.fill",
            title: "Smart Reminders",
            description: "Follow-up alerts if you miss or delay a dose"
        ),
        PremiumFeatureContent(
            icon: "list.bullet.rectangle.portrait",
            title: "Daily Check-Ins",
            description: "Guided wellness, focus, and side-effect reflections"
        )
    ]

    private var bentoColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 160, maximum: .infinity),
                spacing: 12
            )
        ]
    }

    var body: some View {
        ZStack {
            SettingsPalette.backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection

                    featureListSection

                    pricingSection

                    disclaimerSection

                    Spacer(minLength: 20)
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
                hasTriedFeatures = UserDefaults.standard.bool(forKey: "has_used_core_features")
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

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: bentoColumns, spacing: 12) {
                ForEach(premiumFeatures, id: \.title) { feature in
                    BentoFeatureCard(feature: feature)
                }
            }
        }
    }

    private var pricingSection: some View {
        VStack(spacing: 20) {
            oneTimeHighlightCard

            purchaseButtonView(for: storeManager.getPremiumProduct())

            Button(action: { dismiss() }) {
                Text("Continue with Free Version")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
                    .padding(.vertical, 12)
            }
            .accessibilityLabel("Continue with free version of Pillr")

            Button(action: restorePurchases) {
                Text("Restore Purchases")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)
                    .underline(true, color: SettingsPalette.mainText)
                    .padding(.vertical, 6)
            }
        }
    }

    private var oneTimeHighlightCard: some View {
        let priceText = storeManager.getPremiumProduct()?.displayPrice ?? "Unavailable"

        return VStack(spacing: 16) {
            Text("ONE-TIME PURCHASE")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(SettingsPalette.mainText)
                .kerning(1.5)

            Capsule()
                .fill(SettingsPalette.mainText.opacity(0.15))
                .frame(height: 4)
                .padding(.horizontal, 32)
                .accessibilityHidden(true)

            PricingOption(
                title: "Lifetime Premium",
                price: priceText,
                period: "",
                savings: "No subscription required",
                isPopular: true,
                isSelected: true
            ) {}

            Text("Lifetime access. One payment forever.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText)
                .multilineTextAlignment(.center)
                .opacity(0.9)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#556358"),
                            SettingsPalette.cardBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 10)
    }

    @ViewBuilder
    private func purchaseButtonView(for product: Product?) -> some View {
        if let product {
            Button(action: {
                isButtonLoading = true
                purchasePremium(product: product)
            }) {
                HStack(spacing: 8) {
                    if isButtonLoading && !isPreview {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4B534A")))
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    } else {
                        Text("Purchase for \(product.displayPrice)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                }
                .foregroundColor(Color(hex: "#4B534A"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(hex: "#F1F3F0"))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isButtonLoading && !isPreview ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isButtonLoading)
            .disabled(isButtonLoading && !isPreview)
            .accessibilityLabel("Purchase Pillr Premium for \(product.displayPrice)")
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

    private var disclaimerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: "#F1F3F0"))
                    .font(.system(size: 18))

                Text("Medical Disclaimer")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)

                Spacer()
            }

            Text("This app is for tracking purposes only and should not replace professional medical advice. Always consult your healthcare provider regarding your medications.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .background(Color(hex: "#F1F3F0").opacity(0.16))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#F1F3F0").opacity(0.35), lineWidth: 1)
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

private struct PremiumFeatureContent {
    let icon: String
    let title: String
    let description: String
}

private struct BentoFeatureCard: View {
    let feature: PremiumFeatureContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(SettingsPalette.mainText)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            
            Text(feature.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(SettingsPalette.mainText)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(feature.description)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PricingOption: View {
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isPopular: Bool
    let isSelected: Bool
    let action: () -> Void

    init(title: String, price: String, period: String, savings: String? = nil, isPopular: Bool = false, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.price = price
        self.period = period
        self.savings = savings
        self.isPopular = isPopular
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                selectionIndicator

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(SettingsPalette.mainText)

                        if isPopular {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#F1F3F0"))
                                .cornerRadius(4)
                        }

                        Spacer()
                    }

                    HStack {
                        Text(price)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "#F1F3F0"))

                        Text(period)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(SettingsPalette.secondaryText)

                        Spacer()
                    }

                    if let savings {
                        Text(savings)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(SettingsPalette.secondaryText)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
        }
        .buttonStyle(PlainButtonStyle())
        .settingsCardStyle(cornerRadius: 20)
    }

    private var selectionIndicator: some View {
        let selectionColor = SettingsPalette.mainText

        return ZStack {
            Circle()
                .stroke(isSelected ? selectionColor : Color(hex: "#999999").opacity(0.4), lineWidth: 2)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isSelected ? SettingsPalette.mainText.opacity(0.2) : Color.clear)
                        .frame(width: 26, height: 26)
                )

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(selectionColor)
            }
        }
    }
}

#Preview {
    PremiumUpgradeView()
        .environmentObject(StoreManager.previewManager())
}
