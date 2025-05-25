//
//  PrivacyNoticeView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct PrivacyNoticeView: View {
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.dismiss) var dismiss
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(hex: "#C7C7BD").opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(Color(hex: "#81C784"))
                            
                            Spacer()
                        }
                        
                        Text("Your Privacy Matters")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Text("Welcome to Pillr! Here's how we protect your data.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }
                    
                    // Privacy features
                    VStack(spacing: 20) {
                        privacyFeature(
                            icon: "internaldrive.fill",
                            title: "Local Storage Only",
                            description: "All your medications, logs, and notes are stored securely on your device. Nothing is sent to external servers.",
                            iconColor: Color(hex: "#64B5F6")
                        )
                        
                        privacyFeature(
                            icon: "wifi.slash",
                            title: "Core Features Work Offline",
                            description: "All medication tracking works offline. Internet is only used for optional premium AI features.",
                            iconColor: Color(hex: "#FFB74D")
                        )
                        
                        privacyFeature(
                            icon: "eye.slash.fill",
                            title: "No Data Collection",
                            description: "We don't collect, track, or analyze your personal health information. Your privacy is guaranteed.",
                            iconColor: Color(hex: "#FF8A65")
                        )
                        
                        privacyFeature(
                            icon: "person.badge.shield.checkmark.fill",
                            title: "You're In Control",
                            description: "Only you have access to your medication data. Delete the app, and all data is permanently removed.",
                            iconColor: Color(hex: "#81C784")
                        )
                    }
                    
                    // Additional info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Technical Details")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            bulletPoint("Data is stored using iOS UserDefaults and device keychain")
                            bulletPoint("Notifications are handled locally by iOS")
                            bulletPoint("No user accounts or cloud sync required")
                            bulletPoint("Data backup only occurs through your device's iCloud backup (if enabled)")
                            bulletPoint("Optional premium AI features use external services but don't store your data")
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            
            // Action button
            VStack(spacing: 16) {
                Button {
                    HapticManager.shared.mediumImpact()
                    userSettings.markPrivacyNoticeAsShown()
                    onDismiss()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Got It, Thanks!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "#404C42"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#E8E8E0"),
                                Color(hex: "#D0D0C8")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
                
                Text("You can review this information anytime in Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#404C42"),
                    Color(hex: "#3A443D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }
    
    @ViewBuilder
    private func privacyFeature(
        icon: String,
        title: String,
        description: String,
        iconColor: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(iconColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(hex: "#C7C7BD"))
                .frame(width: 4, height: 4)
                .padding(.top, 8)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .lineLimit(nil)
            
            Spacer()
        }
    }
} 