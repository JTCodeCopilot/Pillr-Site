import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var showingPremiumUpgrade = false
    
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
                        
                        appInfoSection
                        
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
            
            // Notifications toggle
            Toggle(isOn: $notificationsEnabled) {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    Text("Enable Notifications")
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
            .onChange(of: notificationsEnabled) { value in
                if value {
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        if settings.authorizationStatus == .notDetermined {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                                if granted {
                                    print("Notification permission granted from settings.")
                                    DispatchQueue.main.async {
                                        self.notificationsEnabled = true
                                    }
                                } else {
                                    print("Notification permission denied from settings.")
                                    DispatchQueue.main.async {
                                        self.notificationsEnabled = false
                                    }
                                }
                            }
                        } else if settings.authorizationStatus == .denied {
                            print("Notification permission was previously denied. Please enable in system settings.")
                            // Optionally, guide user to settings app
                            DispatchQueue.main.async {
                                self.notificationsEnabled = false
                            }
                        }
                        // If .authorized, do nothing, toggle is already on.
                    }
                } else {
                    NotificationManager.shared.cancelAllNotifications()
                }
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
            Button(action: {
                showingPremiumUpgrade = true
            }) {
                HStack {
                    Image(systemName: OpenAIService.shared.isPremiumUser() ? "crown.fill" : "brain.head.profile")
                        .foregroundColor(OpenAIService.shared.isPremiumUser() ? Color(hex: "#FFD700") : Color(hex: "#64B5F6"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(OpenAIService.shared.isPremiumUser() ? "Premium Active" : "Upgrade to Premium")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(OpenAIService.shared.isPremiumUser() ? "AI-powered interaction checking enabled" : "Unlock AI-powered medication analysis")
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if OpenAIService.shared.isPremiumUser() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                        } else {
                            Text("$4.99/mo")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#64B5F6"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#64B5F6").opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                            .font(.system(size: 14))
                    }
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
    
    // Computed property for App Info section
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Text("About")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.2))
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "Version", value: "1.0.0")
                InfoRow(title: "Developer", value: "Justin Tilley")
                InfoRow(title: "Build Date", value: "May 2025")
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