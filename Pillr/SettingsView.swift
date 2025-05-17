import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State private var username: String = ""
    @State private var showSaveMessage = false
    
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
                        
                        // Profile section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Text("Profile")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                            }
                            
                            Divider()
                                .background(Color(hex: "#C7C7BD").opacity(0.2))
                            
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                
                                TextField("Enter username", text: $username)
                                    .padding(10)
                                    .background(Color.black.opacity(0.08))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.1), lineWidth: 0.8)
                                    )
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                            }
                            
                            // Save button
                            Button(action: saveUsername) {
                                Text("Save Changes")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#C7C7BD"))
                                    .cornerRadius(8)
                            }
                            .disabled(username.isEmpty)
                            .opacity(username.isEmpty ? 0.6 : 1.0)
                            
                            if showSaveMessage {
                                Text("Username updated!")
                                    .font(.caption)
                                    .foregroundColor(Color.green)
                                    .padding(.top, 4)
                                    .frame(maxWidth: .infinity, alignment: .center)
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
            .onAppear {
                username = userSettings.userName
            }
        }
    }
    
    private func saveUsername() {
        if !username.isEmpty {
            userSettings.saveUserName(username)
            
            // Show save confirmation
            withAnimation {
                showSaveMessage = true
            }
            
            // Hide message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSaveMessage = false
                }
            }
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
            .preferredColorScheme(.dark)
    }
} 