import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#404C42")
                    .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        HStack {
                            Text("Settings")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.pillrAccent)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        appSettingsSection
                        
                        aiSettingsSection
                        
                        supportLinksSection
                        
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
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
                    .foregroundColor(Color(hex: "#525E55"))
                Text("App Settings")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            Divider()
                .background(Color(hex: "#525E55").opacity(0.15))
            
            // Interaction History
            Button(action: {
                showingInteractionHistory = true
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interaction History")
                            .foregroundColor(Color(hex: "#525E55"))
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("View and manage your interaction checks")
                            .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                            .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())

        }
        .padding()
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // Computed property for AI Settings section
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#525E55"))
                Text("AI Features")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#525E55").opacity(0.15))
            
            // Premium Subscription
            if storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser() {
                // Non-tappable premium status display
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(hex: "#D4A017"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Active")
                            .foregroundColor(Color(hex: "#525E55"))
                            .font(.system(size: 16, weight: .medium))
                        
                        if let subscriptionType = OpenAIService.shared.getSubscriptionType() {
                            Text("\(subscriptionType.capitalized) subscription")
                                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                                .font(.system(size: 14))
                        } else {
                            Text("AI-powered interaction checking enabled")
                                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                                .font(.system(size: 14))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#525E55"))
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
                            .foregroundColor(Color(hex: "#525E55"))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .foregroundColor(Color(hex: "#525E55"))
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Unlock AI-powered medication analysis")
                                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                                .font(.system(size: 14))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // Computed property for Support Links section
    private var supportLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#525E55"))
                Text("Support & Resources")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#525E55").opacity(0.15))
            
            // Privacy Policy Link
            Button(action: {
                if let url = URL(string: "https://tally.so/r/3yR6M4") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    Text("Privacy Policy")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
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
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    Text("Feedback")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
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
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    Text("Contact Us")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
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
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#C7C7BD"))
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSettings.shared)

            .preferredColorScheme(.dark)
    }
} 
