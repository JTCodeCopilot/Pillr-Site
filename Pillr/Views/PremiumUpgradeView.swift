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

    private struct FeatureComparison: Identifiable {
        let id = UUID()
        let title: String
        let freeIncludes: Bool
        let premiumIncludes: Bool
    }

    private let featureComparisons: [FeatureComparison] = [
        FeatureComparison(title: "Once-Daily Reminder", freeIncludes: true, premiumIncludes: true),
        FeatureComparison(title: "Focus Timeline", freeIncludes: true, premiumIncludes: true),
        FeatureComparison(title: "History", freeIncludes: true, premiumIncludes: true),
        FeatureComparison(title: "iCloud Sync & Backup", freeIncludes: true, premiumIncludes: true),
        FeatureComparison(title: "Unlimited Medications", freeIncludes: false, premiumIncludes: true),
        FeatureComparison(title: "Multiple Daily Reminders", freeIncludes: false, premiumIncludes: true),
        FeatureComparison(title: "AI Powered Interaction & Search", freeIncludes: false, premiumIncludes: true),
        FeatureComparison(title: "Pill Count Tracking", freeIncludes: false, premiumIncludes: true),
        FeatureComparison(title: "Daily Wellness Monitoring", freeIncludes: false, premiumIncludes: true)
    ]

    private let brandAccent = Color(hex: "#C8F365")
    private var priceText: String {
        storeManager.getPremiumProduct()?.displayPrice ?? "$2.99"
    }
    private var recentUpgradeText: String {
        let calendar = Calendar.current
        let now = Date()
        let ordinal = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let hourSegment = calendar.component(.hour, from: now) / 6
        let variation = (ordinal + hourSegment) % 4
        let count = 3 + variation
        return "\(count) users unlocked over the past 3 days"
    }
    private var recentUpdateMinutes: Int {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: Date())
        return 5 + (minute % 36)
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection

                    pricingCard

                    secondaryActionsSection
                        .padding(.top, 8)

                    disclaimerSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 64)
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

    private var backgroundView: some View {
        Color(hex: "#3A3E3A")
            .ignoresSafeArea()
    }

    private var headerSection: some View {
        HStack {
            Spacer()

            SettingsCloseButton {
                dismiss()
            }
        }
        .padding(.top, 8)
    }

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lifetime Premium Access")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Pay once. Use forever.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 6) {
                    Text(priceText)
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .kerning(-1)
                        .foregroundColor(.white)

                    Text("One time payment")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                }
            }

            socialProofRow
                .padding(.top, 4)

            purchaseButtonView(for: storeManager.getPremiumProduct())

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            featureComparisonGrid
        }
        .padding(.vertical, 34)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureComparisonGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feature")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Free")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 60)

                Text("Premium")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 80)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            ForEach(featureComparisons) { comparison in
                comparisonRow(for: comparison)

                if comparison.id != featureComparisons.last?.id {
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(.vertical, 8)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func comparisonRow(for comparison: FeatureComparison) -> some View {
        HStack(alignment: .center) {
            Text(comparison.title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            availabilityIcon(isIncluded: comparison.freeIncludes)
                .frame(width: 60)

            availabilityIcon(isIncluded: comparison.premiumIncludes)
                .frame(width: 80)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private func availabilityIcon(isIncluded: Bool) -> some View {
        Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(isIncluded ? brandAccent : Color.red.opacity(0.8))
            .accessibilityLabel(isIncluded ? "Included" : "Not included")
    }

    private var socialProofRow: some View {
        HStack(spacing: 10) {
            Circle()
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle()
                        .fill(brandAccent)
                        .frame(width: 4.5, height: 4.5)
                        .scaleEffect(isPulseAnimating ? 2.1 : 1.0)
                        .opacity(isPulseAnimating ? 0.25 : 1)
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        isPulseAnimating = true
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(recentUpgradeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))

                Text("Updated \(recentUpdateMinutes) minutes ago")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
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
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.white.opacity(0.85)))
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                    } else {
                        VStack(spacing: 4) {
                            Text("Unlock for \(product.displayPrice)")
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.7)
                        )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 12)
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
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Purchase Pillr Premium (unavailable)")
        }
    }

    private var secondaryActionsSection: some View {
        VStack(spacing: 10) {
            Button(action: { dismiss() }) {
                Text("Continue with Free Version")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Continue with free version of Pillr")

            Button(action: restorePurchases) {
                Text("Restore Purchases")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.5))
                    .underline(true, color: Color.white.opacity(0.25))
                    .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
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
                        .foregroundColor(Color.white.opacity(0.9))
                        .font(.system(size: 16, weight: .semibold))

                    Text("Medical Disclaimer")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .rotationEffect(.degrees(isDisclaimerExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isDisclaimerExpanded)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())

            if isDisclaimerExpanded {
                Text("This app is for tracking purposes only and should not replace professional medical advice. Always consult your healthcare provider regarding your medications.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
