import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings

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
                                .foregroundColor(Color(hex: "#C7C7BD"))
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
        }
        .sheet(isPresented: $showingInteractionHistory) {
            InteractionHistoryView()
        }
    }
    
    // Computed property for App Settings section
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Text("App Settings")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Spacer()
            }
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.2))
            
            // Interaction History
            Button(action: {
                showingInteractionHistory = true
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interaction History")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("View and manage your interaction checks")
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            

        }
        .padding()
        .background(Color.black.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#C7C7BD").opacity(0.05), lineWidth: 0.8)
        )
        .padding(.horizontal)
    }
    
    // Computed property for AI Settings section
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Text("AI Features")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.2))
            
            // Premium Subscription
            if OpenAIService.shared.isPremiumUser() {
                // Non-tappable premium status display
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(hex: "#D4A017"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Active")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .font(.system(size: 16, weight: .medium))
                        
                        if let subscriptionType = OpenAIService.shared.getSubscriptionType() {
                            Text("\(subscriptionType.capitalized) subscription")
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .font(.system(size: 14))
                        } else {
                            Text("AI-powered interaction checking enabled")
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .font(.system(size: 14))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#D7CCC8"))
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
                            .foregroundColor(Color(hex: "#D7CCC8"))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Unlock AI-powered medication analysis")
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .font(.system(size: 14))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("$4.99/mo")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#D7CCC8"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#D7CCC8").opacity(0.2))
                                .cornerRadius(8)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.black.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#C7C7BD").opacity(0.05), lineWidth: 0.8)
        )
        .padding(.horizontal)
    }
    
    // Computed property for Support Links section
    private var supportLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Text("Support & Resources")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.2))
            
            // Privacy Policy Link
            Button(action: {
                if let url = URL(string: "https://tally.so/r/3yR6M4") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(Color(hex: "#D7CCC8"))
                        .frame(width: 20)
                    
                    Text("Privacy Policy")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
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
                        .foregroundColor(Color(hex: "#D7CCC8"))
                        .frame(width: 20)
                    
                    Text("Feedback")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
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
                        .foregroundColor(Color(hex: "#D7CCC8"))
                        .frame(width: 20)
                    
                    Text("Contact Us")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.black.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#C7C7BD").opacity(0.05), lineWidth: 0.8)
        )
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