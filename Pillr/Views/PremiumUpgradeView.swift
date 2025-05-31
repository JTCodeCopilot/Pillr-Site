import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isPurchasing = false
    @State private var selectedPlan: String = "one-time"
    @State private var hasTriedFeatures = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#F5F5F5"),
                                                Color(hex: "#C7A76B")
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 90, height: 90)
                                    .shadow(color: Color(hex: "#F5F5F5").opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .accessibilityHidden(true)
                            
                            VStack(spacing: 12) {
                                Text("Pillr Premium")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("Advanced Medication Management")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "#F5F5F5"))
                                
                                Text("Enhance your medication tracking with unlimited medications, AI analysis, and advanced features")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 10)
                        
                        // Features
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Premium Features")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                            
                            PremiumFeature(
                                icon: "pills.fill",
                                title: "Unlimited Medications",
                                description: "Track all of your medications without limits",
                                iconColor: Color(hex: "#F5F5F5")
                            )
                            
                            PremiumFeature(
                                icon: "brain.head.profile",
                                title: "AI Interaction Analysis",
                                description: "Check for potential medication interactions",
                                iconColor: Color(hex: "#F5F5F5")
                            )
                            
                            PremiumFeature(
                                icon: "number.circle.fill",
                                title: "Pill Count Tracking",
                                description: "Monitor inventory and get refill reminders",
                                iconColor: Color(hex: "#F5F5F5")
                            )
                            
                            PremiumFeature(
                                icon: "arrow.clockwise.circle.fill",
                                title: "Smart Reminders",
                                description: "Follow-up alerts if you miss a dose",
                                iconColor: Color(hex: "#F5F5F5")
                            )
                        }
                        
                        // Pricing
                        VStack(spacing: 20) {
                            Text("One-Time Purchase")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            VStack(spacing: 12) {
                                PricingOption(
                                    title: "Lifetime Premium",
                                    price: "$9.99",
                                    period: "one-time payment",
                                    savings: "No subscription required",
                                    isPopular: true,
                                    isSelected: true
                                ) {
                                    // Always selected since it's the only option
                                }
                            }
                            
                            // Purchase button
                            Button(action: {
                                purchasePremium(plan: "one-time")
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Processing...")
                                            .font(.system(size: 18, weight: .semibold))
                                    } else {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Purchase - $9.99")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#D4A017"),
                                            Color(hex: "#D4A017")
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(hex: "#F5F5F5").opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isPurchasing)
                            .scaleEffect(isPurchasing ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isPurchasing)
                            .accessibilityLabel("Purchase Pillr Premium for $9.99")
                            
                            // Continue with free version
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Continue with Free Version")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.vertical, 12)
                            }
                            .accessibilityLabel("Continue with free version of Pillr")
                            
                            // Terms and restore
                            HStack {
                                Button(action: {
                                    // Show terms
                                }) {
                                    Text("Terms of Use")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                        .underline()
                                }
                                
                                Text("•")
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                                
                                Button(action: {
                                    // Restore purchases
                                    restorePurchases()
                                }) {
                                    Text("Restore Purchases")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                        .underline()
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Disclaimer
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                
                                Text("Medical Disclaimer")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Spacer()
                            }
                            
                            Text("This app is for tracking purposes only and should not replace professional medical advice. Always consult your healthcare provider regarding your medications.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Premium Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
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
        .onAppear {
            // Check if user has tried core features before seeing upgrade screen
            hasTriedFeatures = UserDefaults.standard.bool(forKey: "has_used_core_features")
        }
    }
    
    private func purchasePremium(plan: String) {
        isPurchasing = true
        
        // Simulate purchase for development
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPurchasing = false
            alertMessage = "Purchase successful! All premium features are now unlocked."
            showingAlert = true
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        
        // Simulate restore for development
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPurchasing = false
            alertMessage = "Purchases restored successfully."
            showingAlert = true
        }
    }
}

struct PremiumFeature: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
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
                        .stroke(isSelected ? Color(hex: "#D4A017") : Color(hex: "#C7C7BD").opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(isSelected ? Color(hex: "#D4A017") : Color.clear)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        if isPopular {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#D4A017"))
                                .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(price)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#F5F5F5"))
                        
                        Text(period)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                        
                        Spacer()
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5F5F5"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(isSelected ? 0.3 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color(hex: "#F5F5F5") : Color(hex: "#C7C7BD").opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TrustIndicator: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#F5F5F5"))
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
        }
    }
} 
