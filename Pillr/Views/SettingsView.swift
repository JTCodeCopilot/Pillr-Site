import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        appSettingsSection

                        aiSettingsSection

                        supportLinksSection

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(Color(hex: "#F5F7F4"))
                }
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(StoreManager.shared)
        }
        .sheet(isPresented: $showingInteractionHistory) {
            InteractionHistoryView()
        }
        .task {
            // Update purchased products and load products when the view appears
            await storeManager.loadProducts()
            await storeManager.updatePurchasedProducts()
        }
    }
    
    // Computed property for App Settings section
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Text("App Settings")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Spacer()
            }
            Divider()
                .background(Color(hex: "#E0E7DC").opacity(0.15))
            
            // Interaction History
            Button(action: {
                showingInteractionHistory = true
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: "#E0E7DC"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interaction History")
                            .foregroundColor(Color(hex: "#F5F7F4"))
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("View and manage your interaction checks")
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                            .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.6))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())

        }
        .padding()
        .settingsCardStyle()
        .padding(.horizontal)
    }
    
    // Computed property for AI Settings section
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Text("AI Features")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#E0E7DC").opacity(0.15))
            
            // Premium Subscription
            if storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser() {
                // Non-tappable premium status display
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(hex: "#D4A017"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Active")
                            .foregroundColor(Color(hex: "#F5F7F4"))
                            .font(.system(size: 16, weight: .medium))
                        
                        if let subscriptionType = OpenAIService.shared.getSubscriptionType() {
                            Text("\(subscriptionType.capitalized) subscription")
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                                .font(.system(size: 14))
                        } else {
                            Text("AI-powered interaction checking enabled")
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                                .font(.system(size: 14))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .font(.system(size: 16))
                }
                .padding(.vertical, 4)
            } else {
                // Tappable upgrade button
                Button(action: {
                    showingPremiumUpgrade = true
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(Color(hex: "#E0E7DC"))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .foregroundColor(Color(hex: "#F5F7F4"))
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Unlock AI-powered medication analysis")
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                                .font(.system(size: 14))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .settingsCardStyle()
        .padding(.horizontal)
    }
    
    // Computed property for Support Links section
    private var supportLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Text("Support & Resources")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#E0E7DC").opacity(0.15))
            
            // Privacy Policy Link
            Button(action: {
                if let url = URL(string: "https://tally.so/r/3yR6M4") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(Color(hex: "#E0E7DC"))
                        .frame(width: 20)
                    
                    Text("Privacy Policy")
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.6))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Feedback Link
            Button(action: {
                if let url = URL(string: "https://tally.so/r/w2yeXV") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(Color(hex: "#E0E7DC"))
                        .frame(width: 20)
                    
                    Text("Feedback")
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.6))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Contact Us Link
            Button(action: {
                if let url = URL(string: "https://tally.so/r/3qMdL7") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color(hex: "#E0E7DC"))
                        .frame(width: 20)
                    
                    Text("Contact Us")
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.6))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .settingsCardStyle()
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#E0E7DC"))
        }
    }
}

fileprivate extension View {
    func settingsCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#525E55"),
                                Color(hex: "#4A554D"),
                                Color(hex: "#424D45")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
            .shadow(color: Color.white.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSettings.shared)

            .preferredColorScheme(.dark)
    }
} 
