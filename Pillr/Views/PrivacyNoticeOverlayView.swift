//
//  PrivacyNoticeOverlayView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct PrivacyNoticeOverlayView: View {
    @EnvironmentObject var userSettings: UserSettings
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Full screen background with blur
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            // Main content card
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header with welcome message
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(Color(hex: "#81C784"))
                                
                                Spacer()
                            }
                            
                            Text("Welcome to Pillr!")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            Text("Your privacy and data security are our top priorities. Here's how we protect your information.")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                                .lineLimit(nil)
                        }
                        
                        // Privacy features in a more prominent layout
                        VStack(spacing: 20) {
                            privacyFeature(
                                icon: "internaldrive.fill",
                                title: "100% Local Storage",
                                description: "All your medications, logs, and notes are stored securely on your device only. Nothing is sent to external servers.",
                                iconColor: Color(hex: "#64B5F6")
                            )
                            
                            privacyFeature(
                                icon: "wifi.slash",
                                title: "Works Completely Offline",
                                description: "Core medication tracking requires no internet connection. Your data never leaves your device.",
                                iconColor: Color(hex: "#FFB74D")
                            )
                            
                            privacyFeature(
                                icon: "eye.slash.fill",
                                title: "Zero Data Collection",
                                description: "We don't collect, track, or analyze your personal health information. Your privacy is guaranteed.",
                                iconColor: Color(hex: "#FF8A65")
                            )
                            
                            privacyFeature(
                                icon: "person.badge.shield.checkmark.fill",
                                title: "You're In Complete Control",
                                description: "Only you have access to your medication data. Delete the app, and all data is permanently removed.",
                                iconColor: Color(hex: "#81C784")
                            )
                        }
                        
                        // Key technical details
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Technical Guarantee")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            VStack(alignment: .leading, spacing: 14) {
                                techDetail("🔒 Data stored using iOS UserDefaults and device keychain")
                                techDetail("📱 Notifications handled locally by iOS system")
                                techDetail("🚫 No user accounts or cloud sync required")
                                techDetail("💾 Data backup only through your device's iCloud backup (if enabled)")
                                techDetail("🤖 Optional premium AI features use external services but don't store your data")
                            }
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                }
                
                // Action button
                VStack(spacing: 16) {
                    Button {
                        HapticManager.shared.mediumImpact()
                        userSettings.markPrivacyNoticeAsShown()
                        onDismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("I Understand - Let's Get Started!")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "#404C42"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
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
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Text("You can review this information anytime in Settings > Privacy & Data")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 500))
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#404C42"),
                                Color(hex: "#3A443D")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#81C784").opacity(0.3),
                                Color(hex: "#81C784").opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
        }
    }
    
    @ViewBuilder
    private func privacyFeature(
        icon: String,
        title: String,
        description: String,
        iconColor: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                
                Text(description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(iconColor.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
    
    @ViewBuilder
    private func techDetail(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(text.prefix(2)))
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#81C784"))
            
            Text(String(text.dropFirst(2)))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .lineLimit(nil)
            
            Spacer()
        }
    }
} 