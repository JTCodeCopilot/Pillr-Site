import SwiftUI
import StoreKit
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPremiumUpgrade = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        aiSettingsSection
                        notificationSettingsSection

                        supportLinksSection

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 50)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    refreshNotificationSettings()
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
        .task {
            // Update purchased products and load products when the view appears
            await storeManager.loadProducts()
            await storeManager.updatePurchasedProducts()
            refreshNotificationSettings()
        }
    }
    // Computed property for AI Settings section
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
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
                        .foregroundColor(Color(hex: "#F5F7F4"))
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
                        Image(systemName: "hourglass")
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
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notifications")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Spacer()
            }

            Divider()
                .background(Color(hex: "#E0E7DC").opacity(0.15))

            Text("Medication reminders depend on system notifications. Tap below to open the Settings app where you can enable or disable Pillr reminders.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            Text("Status: \(notificationStatusLabel)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#F5F7F4"))

            Button(action: openAppSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open iOS Settings")
                            .foregroundColor(Color(hex: "#F5F7F4"))
                            .font(.system(size: 16, weight: .medium))
                        Text("Manage Pillr notification permissions")
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                            .font(.system(size: 14))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.6))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .settingsCardStyle()
        .padding(.horizontal)
    }

    private var notificationStatusLabel: String {
        guard let status = notificationAuthorizationStatus else { return "Checking..." }
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Enabled – Pillr can deliver reminders."
        case .denied:
            return "Disabled – open Settings to turn reminders back on."
        case .notDetermined:
            return "Not requested yet – reminders will arrive after you allow them."
        @unknown default:
            return "Unknown status"
        }
    }

    private func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    // Computed property for Support Links section
    private var supportLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
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
