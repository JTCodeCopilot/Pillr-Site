import SwiftUI
import StoreKit
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var store: MedicationStore
    @ObservedObject private var storeManager = StoreManager.shared
    @AppStorage("healthSnapshotDistanceUnit") private var distanceUnitRawValue = HealthDistanceUnit.miles.rawValue
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    @State private var showingInteractionSelectionSheet = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus?
    
    var body: some View {
        NavigationView {
            ZStack {
                SettingsPalette.backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        interactionsSection
                        healthSettingsSection
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
        .sheet(isPresented: $showingInteractionHistory) {
            InteractionHistoryView()
                .environmentObject(store)
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $showingInteractionSelectionSheet) {
            MedicationInteractionSelectionSheet()
                .environmentObject(store)
                .environmentObject(storeManager)
        }
        .task {
            // Update purchased products and load products when the view appears
            await storeManager.loadProducts()
            await storeManager.updatePurchasedProducts()
            refreshNotificationSettings()
        }
    }
    
    private var healthSettingsSection: some View {
        settingsSection(title: "Apple Health") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose how Pillr displays your Health distance values. This controls whether steps convert to miles or kilometers in the Health Snapshot.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
                    .lineSpacing(4)
                    .padding(.horizontal, 4)
                
                Picker("Distance Unit", selection: $distanceUnitRawValue) {
                    ForEach(HealthDistanceUnit.allCases) { unit in
                        Text(unit.label).tag(unit.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Health distance unit")
            }
        }
    }
    
    private var interactionsSection: some View {
        settingsSection(title: "AI Interactions") {
            settingsActionRow(
                title: "Check Interactions",
                subtitle: "Compare medications for potential conflicts"
            ) {
                showingInteractionSelectionSheet = true
            }

            settingsActionRow(
                title: "Interaction History",
                subtitle: "Review your past interaction checks"
            ) {
                showingInteractionHistory = true
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
            let premiumActive = storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser()

            if premiumActive {
                settingsActionRow(
                    title: "Premium Purchased",
                    showChevron: false,
                    trailingIcon: "checkmark"
                ) {}
            } else {
                settingsActionRow(
                    title: "Upgrade to Premium",
                    subtitle: "Unlock AI-powered medication analysis",
                    showChevron: false
                ) {
                    showingPremiumUpgrade = true
                }
            }

            settingsActionRow(title: "Privacy Policy") {
                openLink("https://tally.so/r/3yR6M4")
            }

            settingsActionRow(title: "Feedback") {
                openLink("https://tally.so/r/w2yeXV")
            }

            settingsActionRow(title: "Contact Us") {
                openLink("https://tally.so/r/3qMdL7")
            }
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

    private func settingsActionRow(
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = true,
        trailingIcon: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SettingsMetrics.rowSpacing) {
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

                if let iconName = trailingIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SettingsPalette.secondaryText)
                        .padding(.top, 2)
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SettingsPalette.secondaryText)
                        .padding(.top, 2)
                }
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
            .environmentObject(MedicationStore.shared)

            .preferredColorScheme(.dark)
    }
} 
