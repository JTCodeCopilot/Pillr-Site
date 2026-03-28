import SwiftUI
import StoreKit
import UIKit
import UserNotifications
import LocalAuthentication
import WebKit

struct SettingsView: View {
    private enum ScrollTarget: Hashable {
        case feedbackForm
    }

    private enum ICloudDriveStatus {
        case checking
        case available
        case unavailable
    }

    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var store: MedicationStore
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var backupManager = LocalBackupManager.shared
    @AppStorage("healthSnapshotDistanceUnit") private var distanceUnitRawValue = HealthDistanceUnit.miles.rawValue
    @AppStorage("healthSnapshotDailyStepGoal") private var dailyStepGoal = 10000
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    @State private var showingInteractionSelectionSheet = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus?
    @State private var iCloudDriveStatus: ICloudDriveStatus = .checking
    @State private var isHealthSettingsExpanded = false
    @State private var isPremiumSettingsExpanded = false
    @State private var isHomeShortcutsExpanded = false
    @State private var isUpdatingBiometricLock = false
    @State private var biometricAlertMessage: String?
    @State private var notificationTestMessage: String?
    @State private var isSchedulingTestReminder = false

    private var isPremiumActive: Bool {
        storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SettingsPalette.backgroundColor
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            headerView(scrollToFeedback: {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(ScrollTarget.feedbackForm, anchor: .top)
                                }
                            })
                            generalSettingsSection
                            homeShortcutsSection
                            securitySection
                            interactionsSection
                            notificationPermissionsSection
                            backupSection
                            supportLinksSection
                            feedbackFormSection
                                .id(ScrollTarget.feedbackForm)
                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 70)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    refreshNotificationSettings()
                    Task {
                        await refreshICloudStatus()
                    }
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
        .alert(
            "App Lock",
            isPresented: Binding(
                get: { biometricAlertMessage != nil },
                set: { newValue in
                    if !newValue { biometricAlertMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                biometricAlertMessage = nil
            }
        } message: {
            Text(biometricAlertMessage ?? "")
        }
        .alert(
            "Test Reminder",
            isPresented: Binding(
                get: { notificationTestMessage != nil },
                set: { newValue in
                    if !newValue { notificationTestMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                notificationTestMessage = nil
            }
        } message: {
            Text(notificationTestMessage ?? "")
        }
    }

    private func headerView(scrollToFeedback: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color.pillrBackground)

                Text("Tailor your Pillr experience")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.pillrSecondary.opacity(0.9))
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    scrollToFeedback()
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
                .contentShape(Circle())
                .accessibilityLabel("Feedback")
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
    
    private var backupSection: some View {
        settingsSection(title: "Backup") {
            settingsStatusRow(
                iconName: "icloud",
                title: "Connection",
                value: backupConnectionTitle,
                detail: backupConnectionDetail,
                valueColor: backupConnectionColor
            )

            settingsStatusRow(
                iconName: "arrow.triangle.2.circlepath",
                title: "Last backup",
                value: backupLastSavedTitle,
                detail: backupLastSavedDetail
            )

            settingsActionRow(
                title: "Back up now",
                subtitle: "Save your latest app data to iCloud Drive.",
                showChevron: false,
                accessoryIcon: nil,
                leadingIcon: "icloud",
                trailingIcon: nil
            ) {
                backupManager.performBackupNow()
            }

            settingsActionRow(
                title: "Restore from backup",
                subtitle: "Restore the latest saved backup from iCloud Drive.",
                showChevron: false,
                accessoryIcon: nil,
                leadingIcon: "arrow.down.doc",
                trailingIcon: nil
            ) {
                backupManager.restoreLatestBackup { success in
                    guard success else { return }
                    userSettings.reloadFromStorage()
                    store.loadMedications()
                    store.loadLogs()
                    InteractionStore.shared.reloadFromStorage()
                    store.checkAndResetBadge()
                    store.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
                }
            }

            Text("Pillr now keeps your data on this device and saves a backup copy to iCloud Drive.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText.opacity(0.9))
                .multilineTextAlignment(.leading)
                .padding(.top, 8)
        }
    }
    
    private var generalSettingsSection: some View {
        let premiumActive = isPremiumActive
        return settingsSection(title: "Settings") {

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

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Daily step goal")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(SettingsPalette.mainText)
                                Spacer()
                                Text(formattedStepGoal)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(SettingsPalette.secondaryText)
                            }

                            Stepper(value: $dailyStepGoal, in: 1000...50000, step: 500) {
                                Text("Adjust your goal")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(SettingsPalette.secondaryText)
                            }
                        }
                        
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

    private var homeShortcutsSection: some View {
        settingsSection(title: "Home Shortcuts") {
            collapsibleSettingsSection(
                title: "Customize Menu Tabs",
                isExpanded: $isHomeShortcutsExpanded,
                titleFont: .system(size: 16, weight: .medium, design: .rounded),
                titleColor: SettingsPalette.mainText
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose which bottom menu tabs show up. My Meds and More always stay on.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(SettingsPalette.secondaryText)
                        .lineSpacing(4)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        homeShortcutLockedRow(
                            title: "My Meds",
                            subtitle: "Always visible"
                        )

                        homeShortcutLockedRow(
                            title: "More",
                            subtitle: "Always visible"
                        )

                        homeShortcutToggleRow(
                            title: "History",
                            subtitle: "Show the History tab",
                            isOn: Binding(
                                get: { userSettings.isHistoryTabEnabled },
                                set: { userSettings.isHistoryTabEnabled = $0 }
                            )
                        )

                        homeShortcutToggleRow(
                            title: "Reflection",
                            subtitle: "Show the Reflection tab",
                            isOn: Binding(
                                get: { userSettings.isReflectionTabEnabled },
                                set: { userSettings.isReflectionTabEnabled = $0 }
                            )
                        )

                        homeShortcutToggleRow(
                            title: "Timeline",
                            subtitle: "Show the Timeline tab",
                            isOn: Binding(
                                get: { userSettings.isTimelineTabEnabled },
                                set: { userSettings.isTimelineTabEnabled = $0 }
                            )
                        )
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

            Text("For the most reliable reminders, leave Pillr running in the background and avoid force-closing it after setting up medications.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText.opacity(0.95))
                .lineSpacing(4)
                .padding(.horizontal, 4)

            settingsActionRow(
                title: "Manage Notifications",
                subtitle: "Open the iOS notification settings for Pillr",
                leadingIcon: "bell.badge.fill",
                action: openNotificationSettings
            )

            settingsActionRow(
                title: isSchedulingTestReminder ? "Scheduling test reminder..." : "Send test reminder",
                subtitle: "Schedules a test Pillr reminder in about 10 seconds",
                showChevron: false,
                leadingIcon: "bell.and.waves.left.and.right.fill",
                action: sendTestReminder
            )
            .disabled(isSchedulingTestReminder)
            .opacity(isSchedulingTestReminder ? 0.75 : 1)
        }
    }

    private var securitySection: some View {
        settingsSection(title: "Security") {
            Toggle(isOn: biometricLockBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(biometricToggleTitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(SettingsPalette.mainText)

                    Text(biometricToggleSubtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(SettingsPalette.secondaryText)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SettingsPalette.toggleActive))
            .disabled(isUpdatingBiometricLock || availableBiometryType == .none)
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

    private func sendTestReminder() {
        guard !isSchedulingTestReminder else { return }
        isSchedulingTestReminder = true
        NotificationManager.shared.scheduleTestReminder { success in
            isSchedulingTestReminder = false
            if success {
                notificationTestMessage = "Test reminder scheduled. You should get a Pillr notification in about 10 seconds."
            } else {
                notificationTestMessage = "Pillr could not schedule a test reminder. Please allow notifications for Pillr in iPhone Settings and try again."
            }
        }
    }
    
    private var appleHealthVisibilityBinding: Binding<Bool> {
        Binding(
            get: { userSettings.shouldShowAppleHealthData },
            set: { userSettings.shouldShowAppleHealthData = $0 }
        )
    }

    private enum SettingsBiometryType {
        case none
        case faceID
        case touchID
    }

    private var availableBiometryType: SettingsBiometryType {
        if UserSettings.isUITestMode {
            return .faceID
        }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    private var biometricToggleTitle: String {
        switch availableBiometryType {
        case .faceID:
            return "Lock app with Face ID"
        case .touchID:
            return "Lock app with Touch ID"
        case .none:
            return "Biometric app lock"
        }
    }

    private var biometricToggleSubtitle: String {
        switch availableBiometryType {
        case .faceID:
            return "Require Face ID before opening your medications."
        case .touchID:
            return "Require Touch ID before opening your medications."
        case .none:
            return "Face ID or Touch ID is not available on this device."
        }
    }

    private var biometricLockBinding: Binding<Bool> {
        Binding(
            get: { userSettings.isBiometricLockEnabled },
            set: { wantsEnabled in
                updateBiometricLockState(wantsEnabled)
            }
        )
    }

    private func updateBiometricLockState(_ wantsEnabled: Bool) {
        if !wantsEnabled {
            userSettings.setBiometricLockEnabled(false)
            return
        }

        guard availableBiometryType != .none else {
            biometricAlertMessage = "Face ID or Touch ID is not available on this device."
            userSettings.setBiometricLockEnabled(false)
            return
        }

        guard !isUpdatingBiometricLock else { return }
        isUpdatingBiometricLock = true

        if UserSettings.isUITestMode {
            userSettings.setBiometricLockEnabled(true)
            isUpdatingBiometricLock = false
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Not now"

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Enable app lock to protect your medications."
        ) { success, error in
            DispatchQueue.main.async {
                isUpdatingBiometricLock = false
                userSettings.setBiometricLockEnabled(success)

                guard !success else { return }
                if let laError = error as? LAError {
                    switch laError.code {
                    case .userCancel, .systemCancel, .appCancel:
                        return
                    case .biometryNotEnrolled:
                        biometricAlertMessage = "Set up Face ID or Touch ID in iPhone Settings, then try again."
                    case .biometryNotAvailable:
                        biometricAlertMessage = "Face ID or Touch ID is not available on this device."
                    case .biometryLockout:
                        biometricAlertMessage = "Biometrics are temporarily locked. Unlock with your passcode, then try again."
                    default:
                        biometricAlertMessage = "Couldn’t enable app lock right now. Please try again."
                    }
                } else {
                    biometricAlertMessage = "Couldn’t enable app lock right now. Please try again."
                }
            }
        }
    }

    private var supportLinksSection: some View {
        return settingsSection(title: "Support & Resources") {
            settingsActionRow(title: "Privacy Policy") {
                openLink("https://tally.so/r/3yR6M4")
            }

            settingsActionRow(title: "Review Pillr") {
                openLink("https://apps.apple.com/us/app/pillr-adhd-medication-tracker/id6746717689?action=write-review")
            }
        }
    }

    private var feedbackFormSection: some View {
        settingsSection {
            EmbeddedFormView(urlString: "https://tally.so/embed/Ek0jVB?alignLeft=1&transparentBackground=1&dynamicHeight=1")
                .frame(height: 490)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            settingsActionRow(
                title: "Open Full Form",
                subtitle: "Use this if the form does not load properly inside the app",
                showChevron: false,
                leadingIcon: "arrow.up.right.square",
                action: {
                    openLink("https://tally.so/embed/Ek0jVB?alignLeft=1&transparentBackground=1&dynamicHeight=1")
                }
            )
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
                HapticManager.shared.softImpact()
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

    @ViewBuilder
    private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .settingsCardStyle()
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
        .buttonStyle(SettingsActionRowButtonStyle())
    }

    private func homeShortcutToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: SettingsPalette.toggleActive))
    }

    private func homeShortcutLockedRow(
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(SettingsPalette.mainText)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(SettingsPalette.secondaryText)
            }

            Spacer()

            Text("On")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(SettingsPalette.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
        }
        .padding(.vertical, 4)
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
            return Color.pillrAccent
        case .denied, .notDetermined:
            return Color(hex: "#F87171")
        @unknown default:
            return SettingsPalette.mainText
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
        let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.app.Pillr")
        iCloudDriveStatus = containerURL == nil ? .unavailable : .available
    }

    private var backupConnectionTitle: String {
        switch iCloudDriveStatus {
        case .available:
            return "Connected"
        case .unavailable:
            return "Unavailable"
        case .checking:
            return "Checking…"
        }
    }

    private var backupConnectionDetail: String {
        switch iCloudDriveStatus {
        case .available:
            return "Backups can be saved to iCloud Drive."
        case .unavailable:
            return "iCloud Drive is not available right now. Check that iCloud Drive is turned on for this device."
        case .checking:
            return "Checking whether iCloud Drive is ready."
        }
    }

    private var backupConnectionColor: Color {
        switch iCloudDriveStatus {
        case .available:
            return Color.pillrAccent
        case .unavailable:
            return Color(hex: "#F87171")
        case .checking:
            return SettingsPalette.mainText
        }
    }

    private var backupLastSavedTitle: String {
        guard let date = backupManager.lastBackupDate else {
            return "No backup yet"
        }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private var backupLastSavedDetail: String? {
        guard backupManager.lastBackupDate != nil else {
            return "Pillr will create a backup after your data changes."
        }
        return nil
    }

    private var formattedStepGoal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: dailyStepGoal)) ?? "\(dailyStepGoal)"
    }
}

private struct SettingsActionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.pillrSecondary.opacity(0.9))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(Color.pillrSecondary)
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

private struct EmbeddedFormView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let currentURL = webView.url?.absoluteString, currentURL != urlString,
              let url = URL(string: urlString) else {
            return
        }

        webView.load(URLRequest(url: url))
    }
}
