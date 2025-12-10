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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#4B534A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 3) {
                            PremiumFeature(
                                icon: "pills.fill",
                                title: "Unlimited Medications",
                                description: "Track all of your medications without limits",
                                iconColor: Color(hex: "#F1F3F0")
                            )

                            PremiumFeature(
                                icon: "hourglass",
                                title: "AI Interaction Analysis",
                                description: "Check for potential medication interactions",
                                iconColor: Color(hex: "#F1F3F0")
                            )

                            PremiumFeature(
                                icon: "number.circle.fill",
                                title: "Pill Count Tracking",
                                description: "Monitor inventory and get refill reminders",
                                iconColor: Color(hex: "#F1F3F0")
                            )

                            PremiumFeature(
                                icon: "arrow.clockwise.circle.fill",
                                title: "Smart Reminders",
                                description: "Follow-up alerts if you miss a dose",
                                iconColor: Color(hex: "#F1F3F0")
                            )
                        }
                        .padding(.top, 10)
                        
                        // Pricing
                        VStack(spacing: 24) {
                            Text("ONE-TIME PURCHASE")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFFFFF"))
                                .kerning(1.3)
                                .padding(.top, 2)
                            
                            VStack(spacing: 12) {
                                if let product = storeManager.getPremiumProduct() {
                                    PricingOption(
                                        title: "Lifetime Premium",
                                        price: product.displayPrice,
                                        period: "",
                                        savings: "No subscription required",
                                        isPopular: true,
                                        isSelected: true
                                    ) {}
                                } else {
                                    PricingOption(
                                        title: "Lifetime Premium",
                                        price: "Unavailable",
                                        period: "",
                                        savings: "No subscription required",
                                        isPopular: true,
                                        isSelected: true
                                    ) {}
                                }
                            }
                            
                            // Purchase button
                            if let product = storeManager.getPremiumProduct() {
                                Button(action: {
                                    isButtonLoading = true
                                    purchasePremium(product: product)
                                }) {
                                    HStack(alignment: .center, spacing: 2) {
                                        if isButtonLoading && !isPreview {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4B534A")))
                                                .scaleEffect(0.8)
                                            Text("Processing...")
                                                .font(.system(.callout, weight: .medium))
                                        } else {
                                            Text("Purchase for \(product.displayPrice)")
                                                .font(.system(.callout, weight: .medium))
                                        }
                                    }
                                    .foregroundColor(Color(hex: "#4B534A"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 23)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#F1F3F0"),
                                                Color(hex: "#F1F3F0")
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: Color(hex: "#F1F3F0").opacity(0.4), radius: 10, x: 0, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(isButtonLoading && !isPreview ? 0.98 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isButtonLoading)
                                .disabled(isButtonLoading && !isPreview)
                                .accessibilityLabel("Purchase Pillr Premium for \(product.displayPrice)")
                                .padding(.top, 4)
                            } else {
                                Button(action: {
                                    alertMessage = "Products are currently unavailable. Please try again later."
                                    showingAlert = true
                                }) {
                                    HStack(alignment: .center, spacing: 2) {
                                        if isButtonLoading && !isPreview {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4B534A")))
                                                .scaleEffect(0.8)
                                            Text("Processing...")
                                                .font(.system(.callout, weight: .medium))
                                        } else {
                                            Text("Purchase Unavailable")
                                                .font(.system(.callout, weight: .medium))
                                        }
                                    }
                                    .foregroundColor(Color(hex: "#4B534A"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 23)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#F1F3F0"),
                                                Color(hex: "#F1F3F0")
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: Color(hex: "#F1F3F0").opacity(0.4), radius: 10, x: 0, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(isButtonLoading && !isPreview ? 0.98 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isButtonLoading)
                                .disabled(isButtonLoading && !isPreview)
                                .accessibilityLabel("Purchase Pillr Premium (unavailable)")
                                .padding(.top, 4)
                            }
                            
                            // Continue with free version
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Continue with Free Version")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Color(hex: "#CCCCCC").opacity(0.8))
                                    .padding(.vertical, 12)
                            }
                            .accessibilityLabel("Continue with free version of Pillr")
                            .padding(.top, 4)
                            
                            // Restore purchases
                            Button(action: {
                                restorePurchases()
                            }) {
                                Text("Restore Purchases")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "#F1F3F0"))
                                    .underline(true, color: Color(hex: "#F1F3F0"))
                                    .padding(.vertical, 8)
                            }
                            .padding(.top, 6)
                        }
                        
                        // Disclaimer
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color(hex: "#F1F3F0"))
                                    .font(.system(size: 18))
                                
                                Text("Medical Disclaimer")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#FFFFFF"))
                                
                                Spacer()
                            }
                            
                            Text("This app is for tracking purposes only and should not replace professional medical advice. Always consult your healthcare provider regarding your medications.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(14)
                        .background(Color(hex: "#F1F3F0").opacity(0.16))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "#F1F3F0").opacity(0.35), lineWidth: 1)
                        )
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Premium Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                    }
                    .contentShape(Circle())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close premium upgrade sheet")
                }
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
                // Force reload products to ensure we get current regional pricing
                await storeManager.loadProducts()
                
                // Log the user's locale for debugging
                print("User locale: \(Locale.current.identifier)")
                print("User region: \(Locale.current.regionCode ?? "Unknown")")
                print("User currency: \(Locale.current.currencyCode ?? "Unknown")")
                
                // Check if user has tried core features before seeing upgrade screen
                hasTriedFeatures = UserDefaults.standard.bool(forKey: "has_used_core_features")
                
                // Check for existing purchases when view appears
                await storeManager.updatePurchasedProducts()
                
                // If user has already purchased premium, dismiss the view
                if storeManager.isPremiumPurchased() {
                    alertMessage = "You've already purchased Premium!"
                    showingAlert = true
                }
            }
        }
    }
    
    private func purchasePremium(product: Product) {
        Task {
            do {
                // Attempt to purchase the product
                if let transaction = try await storeManager.purchase(product) {
                    // Purchase successful
                    alertMessage = "Purchase successful! All premium features are now unlocked."
                    showingAlert = true
                    
                    // Update user settings to reflect premium status
                    OpenAIService.shared.setPremiumPurchased()
                }
                isButtonLoading = false
            } catch {
                // Purchase failed
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
                // Attempt to restore purchases
                try await storeManager.restorePurchases()
                
                if storeManager.isPremiumPurchased() {
                    alertMessage = "Purchases restored successfully."
                    showingAlert = true
                    
                    // Update user settings to reflect premium status
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

// Extension to add computed property for StoreKit Product for automatic price localization
extension Product {
    var displayPrice: String {
        self.localizedDisplayPrice
    }
}

struct PremiumFeature: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#FFFFFF"))
                    
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(iconColor.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
        let selectionColor = Color(hex: "#4B534A")
        Button(action: action) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? selectionColor : Color(hex: "#999999").opacity(0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(isSelected ? Color(hex: "#F1F3F0").opacity(0.5) : Color.clear)
                                .frame(width: 26, height: 26)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(selectionColor)
                    }
                }
                
                    VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#FFFFFF"))
                        
                        if isPopular {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#F1F3F0"))
                                .cornerRadius(4)
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(price)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(Color(hex: "#F1F3F0"))
                        
                        Text(period)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                        
                        Spacer()
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.32))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color(hex: "#F1F3F0").opacity(0.45) : Color(hex: "#999999").opacity(0.15),
                                lineWidth: isSelected ? 1.4 : 0.7
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PremiumUpgradeView()
        .environmentObject(StoreManager())
}
