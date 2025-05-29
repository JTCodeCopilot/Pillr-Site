import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isPurchasing = false
    @State private var selectedPlan: String = "one-time"
    
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
                            
                            VStack(spacing: 12) {
                                Text("Unlock Premium")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("Medication Management")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(hex: "#F5F5F5"))
                                
                                Text("Get unlimited medications, AI-powered analysis, follow-up reminders, and advanced features")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 10)
                        
                        // Features
                        VStack(spacing: 20) {
                            PremiumFeature(
                                icon: "pills.fill",
                                title: "Unlimited Medications",
                                description: "Add as many medications as you need without the 5-medication limit of the free tier",
                                iconColor: Color(hex: "#F5F5F5")
                            )
                            
                            PremiumFeature(
                                icon: "brain.head.profile",
                                title: "AI Interaction Analysis",
                                description: "Advanced AI analyzes your medications for potential interactions using the latest medical knowledge",
                                iconColor: Color(hex: "#F5F5F5")
                            )
                            
                            PremiumFeature(
                                icon: "arrow.clockwise.circle.fill",
                                title: "Follow-up Reminders",
                                description: "Get a second reminder 30 minutes later if you haven't taken your medication",
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
                                    title: "Premium Upgrade",
                                    price: "$9.99",
                                    period: "one-time",
                                    savings: "No recurring fees",
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
                                        Text("Buy Premium - $9.99")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#B57EDC"),
                                            Color(hex: "#B57EDC")
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
                            
                            // Trust indicators
                            HStack(spacing: 20) {
                                TrustIndicator(icon: "lock.shield.fill", text: "Secure")
                                TrustIndicator(icon: "checkmark.seal.fill", text: "One-Time")
                                TrustIndicator(icon: "infinity", text: "Lifetime Access")
                            }
                            .padding(.top, 8)
                        }
                        
                        // Disclaimer
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                
                                Text("Important Medical Disclaimer")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Spacer()
                            }
                            
                            Text("This AI analysis is for informational purposes only and should not replace professional medical advice. Always consult your healthcare provider before making any changes to your medication regimen.")
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
                    Button("Cancel") {
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
    }
    
    private func purchasePremium(plan: String) {
        isPurchasing = true
        HapticManager.shared.lightImpact()
        
        // Simulate purchase process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // For demo purposes, automatically grant premium
            OpenAIService.shared.setPremiumPurchased()
            HapticManager.shared.successNotification()
            
            alertMessage = "Premium purchase successful! You now have lifetime access to unlimited medications, AI-powered features, and follow-up reminders."
            showingAlert = true
            isPurchasing = false
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
                        .stroke(isSelected ? Color(hex: "#B57EDC") : Color(hex: "#C7C7BD").opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(isSelected ? Color(hex: "#B57EDC") : Color.clear)
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
                                .background(Color(hex: "#B57EDC"))
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
