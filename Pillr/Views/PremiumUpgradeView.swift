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
                Color(hex: "#525E55").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#D4AF37"),
                                                Color(hex: "#D4AF37")
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: Color(hex: "#ffffff").opacity(0.4), radius: 12, x: 0, y: 5)
                                
                                Image(systemName: "hourglass")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .accessibilityHidden(true)
                            .padding(.top, 10)
                            
                            VStack(spacing: 14) {
                                Text("Pillr Premium")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFFFFF"))
                                
                                Text("Advanced Management")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "#D4AF37"))
                                
                            }
                        }
                        
                        // Features
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Premium Features")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "#FFFFFF"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            
                            PremiumFeature(
                                icon: "pills.fill",
                                title: "Unlimited Medications",
                                description: "Track all of your medications without limits",
                                iconColor: Color(hex: "#D4AF37")
                            )
                            
                            PremiumFeature(
                                icon: "hourglass",
                                title: "AI Interaction Analysis",
                                description: "Check for potential medication interactions",
                                iconColor: Color(hex: "#D4AF37")
                            )
                            
                            PremiumFeature(
                                icon: "number.circle.fill",
                                title: "Pill Count Tracking",
                                description: "Monitor inventory and get refill reminders",
                                iconColor: Color(hex: "#D4AF37")
                            )
                            
                            PremiumFeature(
                                icon: "arrow.clockwise.circle.fill",
                                title: "Smart Reminders",
                                description: "Follow-up alerts if you miss a dose",
                                iconColor: Color(hex: "#D4AF37")
                            )
                        }
                        
                        // Pricing
                        VStack(spacing: 24) {
                            Text("ONE-TIME PURCHASE")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "#FFFFFF"))
                            
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
                                    HStack {
                                        if isButtonLoading && !isPreview {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                            Text("Processing...")
                                                .font(.system(size: 18, weight: .semibold))
                                        } else {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 18, weight: .bold))
                                            
                                            Text("Purchase for \(product.displayPrice)")
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#D4AF37"),
                                                Color(hex: "#D4AF37")
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "#D4AF37").opacity(0.5), radius: 10, x: 0, y: 4)
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
                                    HStack {
                                        if isButtonLoading && !isPreview {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                            Text("Processing...")
                                                .font(.system(size: 18, weight: .semibold))
                                        } else {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 18, weight: .bold))
                                            
                                            Text("Purchase Unavailable")
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#D4AF37"),
                                                Color(hex: "#D4AF37")
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "#D4AF37").opacity(0.5), radius: 10, x: 0, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(isButtonLoading && !isPreview ? 0.98 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isButtonLoading)
                                .disabled(isButtonLoading && !isPreview)
                                .accessibilityLabel("Purchase Pillr Premium (unavailable)")
                            }
                            
                            // Continue with free version
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Continue with Free Version")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#CCCCCC"))
                                    .padding(.vertical, 12)
                            }
                            .accessibilityLabel("Continue with free version of Pillr")
                            
                            // Restore purchases
                            Button(action: {
                                restorePurchases()
                            }) {
                                Text("Restore Purchases")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "#D4AF37"))
                                    .underline()
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Disclaimer
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color(hex: "#D4AF37"))
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
                        .padding(8)
                        .background(Color(hex: "#D4AF37").opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#D4AF37").opacity(0.3), lineWidth: 1)
                        )
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Premium Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFFFF"))
                    .font(.system(size: 16, weight: .medium))
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
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 54, height: 54)
                
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
        .padding(16)
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "#D4AF37") : Color(hex: "#999999").opacity(0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(isSelected ? Color(hex: "#D4AF37") : Color.clear)
                                .frame(width: 26, height: 26)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#FFFFFF"))
                        
                        if isPopular {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#D4AF37"))
                                .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(price)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "#D4AF37"))
                        
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
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color(hex: "#D4AF37") : Color(hex: "#999999").opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PremiumUpgradeView()
        .environmentObject(StoreManager())
}
