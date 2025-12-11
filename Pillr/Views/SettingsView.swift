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
                SettingsPalette.backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        settingsHeader
                        aiSettingsSection
                        notificationSettingsSection
                        supportLinksSection
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 70)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    refreshNotificationSettings()
                }
            }
            .navigationBarHidden(true)
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
        settingsSection(title: "AI Features") {
            if storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser() {
                let subscriptionDescription = OpenAIService.shared.getSubscriptionType()
                    .map { "\($0.capitalized) subscription" }
                    ?? "AI-powered interaction checking enabled"

                HStack(alignment: .top, spacing: SettingsMetrics.rowSpacing) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: SettingsMetrics.rowIconSize, weight: .semibold, design: .rounded))
                        .foregroundColor(SettingsPalette.mainText)
                        .frame(width: SettingsMetrics.rowIconFrame, height: SettingsMetrics.rowIconFrame, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium Active")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(SettingsPalette.mainText)

                        Text(subscriptionDescription)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(SettingsPalette.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#7CD4BA"))
                        .frame(width: 24, height: 24)
                }
                .padding(.vertical, 10)
            } else {
                settingsActionRow(
                    iconName: "hourglass",
                    title: "Upgrade to Premium",
                    subtitle: "Unlock AI-powered medication analysis"
                ) {
                    showingPremiumUpgrade = true
                }
            }
        }
    }
    
    private var notificationSettingsSection: some View {
        settingsSection(title: "Notifications") {
            Text("Medication reminders depend on system notifications. Tap below to open the Settings app where you can enable or disable Pillr reminders.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText)
                .lineSpacing(4)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Status: \(notificationStatusValue)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)
                Text(notificationStatusContext)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
            }

            settingsActionRow(
                iconName: "gearshape.fill",
                title: "Open iOS Settings",
                subtitle: "Manage Pillr notification permissions",
                action: openAppSettings
            )
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
        openLink(UIApplication.openSettingsURLString)
    }
    
    private var supportLinksSection: some View {
        settingsSection(title: "Support & Resources") {
            settingsActionRow(iconName: "hand.raised.fill", title: "Privacy Policy") {
                openLink("https://tally.so/r/3yR6M4")
            }

            settingsActionRow(iconName: "message.fill", title: "Feedback") {
                openLink("https://tally.so/r/w2yeXV")
            }

            settingsActionRow(iconName: "envelope.fill", title: "Contact Us") {
                openLink("https://tally.so/r/3qMdL7")
            }
        }
    }

    private var settingsHeader: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(SettingsPalette.mainText)

            Spacer()

            closeButton
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var closeButton: some View {
        SettingsCloseButton {
            dismiss()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsPalette.headerColor)

                Divider()
                    .background(Color.white.opacity(0.08))
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .settingsCardStyle()
    }

    private func settingsActionRow(iconName: String, title: String, subtitle: String? = nil, iconColor: Color = SettingsPalette.mainText, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SettingsMetrics.rowSpacing) {
                Image(systemName: iconName)
                    .font(.system(size: SettingsMetrics.rowIconSize, weight: .semibold, design: .rounded))
                    .foregroundColor(iconColor)
                    .frame(width: SettingsMetrics.rowIconFrame, height: SettingsMetrics.rowIconFrame, alignment: .leading)

                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(SettingsPalette.mainText)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(SettingsPalette.secondaryText)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: SettingsMetrics.arrowSize, weight: .semibold))
                    .foregroundColor(SettingsPalette.arrowColor.opacity(SettingsMetrics.arrowOpacity))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var notificationStatusValue: String {
        guard let status = notificationAuthorizationStatus else {
            return "Checking"
        }

        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not requested yet"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationStatusContext: String {
        guard let status = notificationAuthorizationStatus else {
            return "Waiting for notification status to refresh."
        }

        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Pillr can deliver reminders."
        case .denied:
            return "Open Settings to turn reminders back on."
        case .notDetermined:
            return "Reminders will arrive once you allow them."
        @unknown default:
            return "Status currently unavailable."
        }
    }

    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSettings.shared)

            .preferredColorScheme(.dark)
    }
} 
