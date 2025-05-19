import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var openAIService: OpenAIService
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    
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
                        
                        // App Settings section
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
                                    NotificationManager.shared.requestAuthorization()
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
                        
                        // App info section
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
                        
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
        }
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
            .environmentObject(OpenAIService.shared)
            .preferredColorScheme(.dark)
    }
} 