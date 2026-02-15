import SwiftUI
import StoreKit
import UIKit
import UserNotifications
import CloudKit

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var appTheme: AppTheme
    @ObservedObject private var storeManager = StoreManager.shared
    @AppStorage("healthSnapshotDistanceUnit") private var distanceUnitRawValue = HealthDistanceUnit.miles.rawValue
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    @State private var showingInteractionSelectionSheet = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus?
    @State private var iCloudAccountStatus: CKAccountStatus?
    @State private var isHealthSettingsExpanded = false
    @State private var isPremiumSettingsExpanded = false
    @State private var showingCloudSyncChoiceAgain = false
    @State private var cloudSyncRotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    private var isPremiumActive: Bool {
        storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser()
    }
    
    private var shouldUseCloudSync: Bool {
        userSettings.shouldUseCloudSync
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SettingsPalette.backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerView
                        generalSettingsSection
                        interactionsSection
                        notificationPermissionsSection
                        iCloudSyncSection
                        supportLinksSection
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 70)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    refreshNotificationSettings()
                    Task {
                        await refreshICloudStatus()
                    }
                }
                if showingCloudSyncChoiceAgain {
                    CloudSyncChoiceOverlay { choice in
                        handleCloudSyncSelection(choice)
                    }
                    .transition(.opacity)
                    .zIndex(3)
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
            await refreshICloudStatus()
        }
    }

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F7F4"))

                Text("Tailor your Pillr experience")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    openLink("https://tally.so/r/w2yeXV")
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .background(
                    Group {
                        if colorScheme == .dark {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        }
                    }
                )
                .contentShape(Circle())
                .accessibilityLabel("Feedback")

                Button {
                    openLink("https://tally.so/r/3qMdL7")
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .background(
                    Group {
                        if colorScheme == .dark {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        }
                    }
                )
                .contentShape(Circle())
                .accessibilityLabel("Contact us")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
    
    private var interactionsSection: some View {
        let premiumActive = isPremiumActive
        return settingsSection(title: "AI Interactions") {
            settingsActionRow(
                title: "Check Interactions",
                subtitle: "Compare medications for potential conflicts",
                accessoryIcon: premiumActive ? nil : "lock"
            ) {
                handleInteractionSelectionTap()
            }

            settingsActionRow(
                title: "Interaction History",
                subtitle: "Review your past interaction checks",
                accessoryIcon: premiumActive ? nil : "lock"
            ) {
                handleInteractionHistoryTap()
            }
        }
    }
    
    private var iCloudSyncSection: some View {
        settingsSection(title: "iCloud Sync") {
            settingsStatusRow(
                iconName: "icloud",
                title: "Connection",
                value: iCloudConnectionTitle,
                detail: iCloudConnectionDetail,
                valueColor: iCloudConnectionColor
            )

            settingsStatusRow(
                iconName: "arrow.triangle.2.circlepath",
                title: "Last sync",
                value: iCloudLastSyncTitle,
                detail: iCloudLastSyncDetail
            )

            settingsActionRow(
                title: store.isCloudSyncInProgress ? "Syncing with iCloud..." : "Resync iCloud now",
                subtitle: shouldUseCloudSync
                    ? "Tap to manually fetch your latest iCloud medication data."
                    : "Enable iCloud Sync to manually resync.",
                showChevron: false,
                accessoryIcon: nil,
                leadingIcon: "icloud",
                trailingIcon: shouldUseCloudSync ? nil : "lock"
            ) {
                triggerManualCloudResync()
            }
            .overlay(alignment: .trailing) {
                if shouldUseCloudSync {
                    Image(systemName: store.isCloudSyncInProgress ? "arrow.triangle.2.circlepath.circle.fill" : "icloud")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SettingsPalette.secondaryText)
                        .padding(.top, 2)
                        .rotationEffect(.degrees(cloudSyncRotation))
                        .animation(.easeInOut(duration: 0.2), value: store.isCloudSyncInProgress)
                }
            }
            .disabled(!shouldUseCloudSync || store.isCloudSyncInProgress)
            .opacity(!shouldUseCloudSync ? 0.7 : 1)
            .onAppear {
                updateCloudSyncAnimation(isSyncing: store.isCloudSyncInProgress)
            }
            .onChange(of: store.isCloudSyncInProgress) { _, syncing in
                updateCloudSyncAnimation(isSyncing: syncing)
            }

            if !shouldUseCloudSync {
                Text("You chose to keep everything on this device. Connect to iCloud later whenever you’re ready.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)

                settingsActionRow(
                    title: "Change sync preference",
                    subtitle: "Reopen the iCloud choice screen to enable sync again.",
                    accessoryIcon: "icloud",
                    leadingIcon: "arrow.triangle.2.circlepath",
                    action: {
                        showingCloudSyncChoiceAgain = true
                    }
                )
            }
        }
    }
    
    private var generalSettingsSection: some View {
        let premiumActive = isPremiumActive
        return settingsSection(title: "Settings") {
            settingsThemeModeRow

            VStack(spacing: 14) {
                collapsibleSettingsSection(
                    title: "Apple Health",
                    isExpanded: $isHealthSettingsExpanded,
                    titleFont: .system(size: 16, weight: .medium, design: .rounded),
                    titleColor: SettingsPalette.mainText
                ) {
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
                        
                        Toggle("Show Apple Health data on My Meds screen", isOn: appleHealthVisibilityBinding)
                            .toggleStyle(SwitchToggleStyle(tint: SettingsPalette.toggleActive))
                            .accessibilityLabel("Show Apple Health data on My Meds screen")
                    }
                }
                
                collapsibleSettingsSection(
                    title: premiumActive ? "Premium" : "Upgrade to Premium",
                    isExpanded: $isPremiumSettingsExpanded,
                    titleFont: .system(size: 16, weight: .medium, design: .rounded),
                    titleColor: SettingsPalette.mainText
                ) {
                    if premiumActive {
                        Text("Thank you for supporting Pillr Premium. Enjoy full access to AI-powered analysis.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(SettingsPalette.secondaryText)
                            .lineSpacing(4)
                            .padding(.horizontal, 4)

                        settingsActionRow(
                            title: "Premium Active",
                            showChevron: false,
                            trailingIcon: "lock.open"
                        ) {}
                    } else {
                        Text("Unlock AI-powered medication analysis and other premium perks.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(SettingsPalette.secondaryText)
                            .lineSpacing(4)
                            .padding(.horizontal, 4)

                        settingsActionRow(
                            title: "Upgrade Now",
                            subtitle: "One-tap purchase",
                            showChevron: false,
                            accessoryIcon: "lock"
                        ) {
                            showingPremiumUpgrade = true
                        }
                    }
                }
            }
        }
    }

    private var notificationPermissionsSection: some View {
        settingsSection(title: "Notifications") {
            Text("Medication reminders depend on system notifications. Use the link below to update permissions.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText)
                .lineSpacing(4)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Status: \(notificationStatusValue)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(notificationStatusColor)
                Text(notificationStatusContext)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
            }

            settingsActionRow(
                title: "Manage Notifications",
                subtitle: "Open the iOS notification settings for Pillr",
                leadingIcon: "bell.badge.fill",
                action: openNotificationSettings
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

    private func openNotificationSettings() {
        if #available(iOS 16.0, *) {
            openLink(UIApplication.openNotificationSettingsURLString)
        } else {
            openLink(UIApplication.openSettingsURLString)
        }
    }
    
    private var appleHealthVisibilityBinding: Binding<Bool> {
        Binding(
            get: { userSettings.shouldShowAppleHealthData },
            set: { userSettings.shouldShowAppleHealthData = $0 }
        )
    }

    private var themeModeBinding: Binding<AppThemeMode> {
        Binding(
            get: { appTheme.mode },
            set: { appTheme.setMode($0) }
        )
    }

    private var supportLinksSection: some View {
        return settingsSection(title: "Support & Resources") {
            settingsActionRow(title: "Privacy Policy") {
                openLink("https://tally.so/r/3yR6M4")
            }

            settingsActionRow(title: "Feedback") {
                openLink("https://tally.so/r/w2yeXV")
            }

            settingsActionRow(title: "Contact Us") {
                openLink("https://tally.so/r/3qMdL7")
            }

            settingsActionRow(title: "Review Pillr") {
                openLink("https://apps.apple.com/us/app/pillr-adhd-medication-tracker/id6746717689?action=write-review")
            }
        }
    }

    private func handleInteractionSelectionTap() {
        if isPremiumActive {
            showingInteractionSelectionSheet = true
        } else {
            showingPremiumUpgrade = true
        }
    }

    private func handleInteractionHistoryTap() {
        if isPremiumActive {
            showingInteractionHistory = true
        } else {
            showingPremiumUpgrade = true
        }
    }

    private func handleCloudSyncSelection(_ choice: CloudSyncChoice) {
        let enableSync = choice == .connect
        userSettings.setCloudSyncPreference(enableSync)
        showingCloudSyncChoiceAgain = false
    }

    @ViewBuilder
    private func collapsibleSettingsSection<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        titleFont: Font = .system(size: 18, weight: .semibold, design: .rounded),
        titleColor: Color = SettingsPalette.headerColor,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85, blendDuration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(titleFont)
                        .foregroundColor(titleColor)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: SettingsMetrics.arrowSize, weight: .semibold))
                        .foregroundColor(SettingsPalette.arrowColor.opacity(SettingsMetrics.arrowOpacity))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded.wrappedValue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded.wrappedValue {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SettingsPalette.nestedCardBackground)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
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

    private var settingsThemeModeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Appearance")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)
                Text("Choose Light, Dark, or follow your iPhone system appearance.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
            }

            Picker("Appearance", selection: themeModeBinding) {
                ForEach(AppThemeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .environment(\.colorScheme, appTheme.isUsingDarkPalette ? .dark : .light)
            .accessibilityLabel("Appearance")
        }
        .padding(.vertical, 10)
    }

    private func settingsActionRow(
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = true,
        accessoryIcon: String? = nil,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: SettingsMetrics.rowSpacing) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: SettingsMetrics.rowIconSize, weight: .semibold))
                        .frame(width: SettingsMetrics.rowIconFrame, height: SettingsMetrics.rowIconFrame)
                        .foregroundColor(SettingsPalette.secondaryText)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
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

                HStack(spacing: 6) {
                    if let iconName = accessoryIcon {
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SettingsPalette.secondaryText)
                            .padding(.top, 2)
                    }

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
        case .denied, .notDetermined:
            return "Disabled"
        @unknown default:
            return "Disabled"
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
            return "Permissions have not been granted yet."
        @unknown default:
            return "Status currently unavailable."
        }
    }

    private var notificationStatusColor: Color {
        guard let status = notificationAuthorizationStatus else {
            return SettingsPalette.mainText
        }

        switch status {
        case .authorized, .provisional, .ephemeral:
            return Color(hex: "#C8F365")
        case .denied, .notDetermined:
            return Color(hex: "#F87171")
        @unknown default:
            return SettingsPalette.mainText
        }
    }

    private func triggerManualCloudResync() {
        guard shouldUseCloudSync else { return }
        store.refreshCloudSyncIfNeeded { _ in
            Task { @MainActor in
                await refreshICloudStatus()
            }
        }
    }

    private func updateCloudSyncAnimation(isSyncing: Bool) {
        if isSyncing {
            cloudSyncRotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                cloudSyncRotation = 360
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                cloudSyncRotation = 0
            }
        }
    }

    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func settingsStatusRow(
        iconName: String,
        title: String,
        value: String,
        detail: String?,
        valueColor: Color = SettingsPalette.mainText
    ) -> some View {
        HStack(alignment: .top, spacing: SettingsMetrics.rowSpacing) {
            Image(systemName: iconName)
                .font(.system(size: SettingsMetrics.rowIconSize, weight: .semibold))
                .frame(width: SettingsMetrics.rowIconFrame, height: SettingsMetrics.rowIconFrame)
                .foregroundColor(valueColor)

            VStack(alignment: .leading, spacing: detail == nil ? 2 : 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)

                Text(value)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(valueColor)

                if let detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(SettingsPalette.secondaryText.opacity(0.9))
                }
            }

            Spacer()
        }
    }

    private func refreshICloudStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            iCloudAccountStatus = status
        } catch {
            print("Failed to read iCloud account status: \(error)")
            iCloudAccountStatus = nil
        }
    }

    private var iCloudConnectionTitle: String {
        if !shouldUseCloudSync {
            return "On-device only"
        }
        switch iCloudAccountStatus {
        case .available:
            return "Connected"
        case .noAccount:
            return "Sign in to iCloud"
        case .restricted:
            return "iCloud Restricted"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        case .couldNotDetermine, .none:
            return "Checking…"
        @unknown default:
            return "Unknown status"
        }
    }

    private var iCloudConnectionDetail: String {
        if !shouldUseCloudSync {
            return "Medication records stay on this device, but you can connect to iCloud anytime from the prompt below."
        }
        switch iCloudAccountStatus {
        case .available:
            return "Your medications and logs are backed up securely."
        case .noAccount:
            return "Open iOS Settings to sign in and enable sync."
        case .restricted:
            return "Restrictions on this device prevent iCloud usage."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again shortly."
        case .couldNotDetermine, .none:
            return "Waiting for iCloud to report your account status."
        @unknown default:
            return "Account status currently unavailable."
        }
    }

    private var iCloudConnectionColor: Color {
        if !shouldUseCloudSync {
            return SettingsPalette.secondaryText
        }
        switch iCloudAccountStatus {
        case .available:
            return Color(hex: "#C8F365")
        case .noAccount, .restricted, .temporarilyUnavailable:
            return Color(hex: "#F87171")
        case .couldNotDetermine, .none:
            return SettingsPalette.mainText
        @unknown default:
            return SettingsPalette.mainText
        }
    }

    private var iCloudLastSyncTitle: String {
        if !shouldUseCloudSync {
            return "Sync disabled"
        }
        guard let date = store.lastCloudSyncDate else {
            return "Not yet synced"
        }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private var iCloudLastSyncDetail: String? {
        if !shouldUseCloudSync {
            return "Last sync tracking is paused while iCloud sync is off."
        }
        guard store.lastCloudSyncDate != nil else {
            return "Waiting for Pillr to finish its first sync"
        }
        return nil
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
            .environmentObject(AppTheme.shared)
    }
} 
