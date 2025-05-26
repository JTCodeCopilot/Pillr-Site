import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isPurchasing = false
    @State private var selectedPlan: String = "yearly"
    
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
                                                Color(hex: "#D9B382"),
                                                Color(hex: "#C7A76B")
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 90, height: 90)
                                    .shadow(color: Color(hex: "#D9B382").opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 12) {
                                Text("Unlock AI-Powered")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("Medication Analysis")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(hex: "#D9B382"))
                                
                                Text("Get intelligent insights about drug interactions with advanced AI technology")
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
                                icon: "brain.head.profile",
                                title: "AI Interaction Analysis",
                                description: "Advanced AI analyzes your medications for potential interactions using the latest medical knowledge",
                                iconColor: Color(hex: "#D9B382")
                            )
                            
                            PremiumFeature(
                                icon: "shield.checkered",
                                title: "Comprehensive Safety Check",
                                description: "Get detailed severity levels, descriptions, and personalized recommendations for each interaction",
                                iconColor: Color(hex: "#D9B382")
                            )
                            
                            PremiumFeature(
                                icon: "clock.arrow.circlepath",
                                title: "Real-time Updates",
                                description: "Always up-to-date with the latest drug interaction research and medical guidelines",
                                iconColor: Color(hex: "#FF9800")
                            )
                            
                            PremiumFeature(
                                icon: "doc.text.magnifyingglass",
                                title: "Detailed Reports",
                                description: "Save and share comprehensive interaction reports with your healthcare providers",
                                iconColor: Color(hex: "#9C27B0")
                            )
                        }
                        
                        // Pricing
                        VStack(spacing: 20) {
                            Text("Choose Your Plan")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            VStack(spacing: 12) {
                                PricingOption(
                                    title: "Yearly",
                                    price: "$39.99",
                                    period: "per year",
                                    savings: "Save 33%",
                                    isPopular: true,
                                    isSelected: selectedPlan == "yearly"
                                ) {
                                    selectedPlan = "yearly"
                                }
                                
                                PricingOption(
                                    title: "Monthly",
                                    price: "$4.99",
                                    period: "per month",
                                    isPopular: false,
                                    isSelected: selectedPlan == "monthly"
                                ) {
                                    selectedPlan = "monthly"
                                }
                            }
                            
                            // Purchase button
                            Button(action: {
                                purchasePremium(plan: selectedPlan)
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
                                        Text("Start Premium")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#D9B382"),
                                            Color(hex: "#C7A76B")
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(hex: "#D9B382").opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isPurchasing)
                            .scaleEffect(isPurchasing ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isPurchasing)
                            
                            // Trust indicators
                            HStack(spacing: 20) {
                                TrustIndicator(icon: "lock.shield.fill", text: "Secure")
                                TrustIndicator(icon: "arrow.clockwise", text: "Cancel Anytime")
                                TrustIndicator(icon: "checkmark.seal.fill", text: "7-Day Trial")
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
            OpenAIService.shared.setPremiumStatus(true)
            OpenAIService.shared.setSubscriptionType(plan)
            HapticManager.shared.successNotification()
            
            alertMessage = "Premium upgrade successful! You now have access to AI-powered interaction checking."
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
                        .stroke(isSelected ? Color(hex: "#D9B382") : Color(hex: "#C7C7BD").opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(isSelected ? Color(hex: "#D9B382") : Color.clear)
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
                                .background(Color(hex: "#FF6B35"))
                                .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(price)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#D9B382"))
                        
                        Text(period)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                        
                        Spacer()
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#D9B382"))
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
                                isSelected ? Color(hex: "#D9B382") : Color(hex: "#C7C7BD").opacity(0.2),
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
                .foregroundColor(Color(hex: "#D9B382"))
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
        }
    }
} 