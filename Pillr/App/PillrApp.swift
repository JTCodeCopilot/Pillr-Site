//
//  PillrApp.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI
import UserNotifications
import TelemetryDeck

// App Delegate to handle application lifecycle events
final class PillrAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            MedicationStore.shared.checkAndResetBadge()
            MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
            NotificationManager.shared.surfaceDeliveredStimulantCheckInsIfNeeded()
            incrementAppLaunchCountIfNeeded()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Foreground-specific work is handled in applicationDidBecomeActive.
    }

    private func incrementAppLaunchCountIfNeeded() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "isRunningPreview") {
            return
        }
        #endif
        let key = "appLaunchCount"
        let currentCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
    }

}

@main
struct PillrApp: App {
    // IMPORTANT: Medication data stays on-device and can be backed up to iCloud Drive.
    // Data is only removed when the app is completely uninstalled.
    
    @UIApplicationDelegateAdaptor private var appDelegate: PillrAppDelegate
    
    @StateObject private var store = MedicationStore.shared
    @StateObject private var interactionStore = InteractionStore.shared
    @StateObject private var userSettings = UserSettings.shared
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var backupManager = LocalBackupManager.shared
    
    init() {
        // Set preview environment detection
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Set flag for previews to optimize rendering speed
            UserDefaults.standard.set(true, forKey: "isRunningPreview")
            
            // Use simplified data models for previews to speed up build time
            UserDefaults.standard.set(true, forKey: "useMinimalDataForPreviews")
            
            // Disable animations in preview mode for faster rendering
            UIView.setAnimationsEnabled(false)
        } else if UserSettings.isUITestMode {
            // Keep test runs stable without wiping user defaults each launch.
            UserDefaults.standard.set(false, forKey: "isRunningPreview")
            UserDefaults.standard.set(true, forKey: "useMinimalDataForPreviews")
            UIView.setAnimationsEnabled(false)
        } else {
            // Clear the preview flag so normal runs aren't treated as previews.
            UserDefaults.standard.set(false, forKey: "isRunningPreview")
        }
        #endif
        
        // Application appearance settings
        configureAppAppearance()
        // Initialize TelemetryDeck analytics
        let telemetryConfig = TelemetryDeck.Config(appID: "1AEFCFCE-EC76-475D-A16E-8AC2A28ECF82")
        TelemetryDeck.initialize(config: telemetryConfig)
    }
    
    private func configureAppAppearance() {
        // Configure navigation bar appearance
        if #available(iOS 26.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = UIColor(Color.pillrPrimary)
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        } else {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(Color.pillrPrimary)
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.pillrSecondary)]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.pillrSecondary)]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Configure tab bar appearance
        let overdueBadgeColor = UIColor(Color(hex: "#F5C4B3"))
        let tabSelectedColor = UIColor(Color(hex: "#8BA091"))
        let tabNormalColor = UIColor(Color(hex: "#5E7266"))
        func applyBadgeColors(to appearance: UITabBarAppearance) {
            let itemAppearances = [
                appearance.stackedLayoutAppearance,
                appearance.inlineLayoutAppearance,
                appearance.compactInlineLayoutAppearance
            ]
            for itemAppearance in itemAppearances {
                itemAppearance.normal.badgeBackgroundColor = overdueBadgeColor
                itemAppearance.selected.badgeBackgroundColor = overdueBadgeColor
                itemAppearance.normal.badgeTextAttributes = [.foregroundColor: UIColor.white]
                itemAppearance.selected.badgeTextAttributes = [.foregroundColor: UIColor.white]
                itemAppearance.normal.iconColor = tabNormalColor.withAlphaComponent(0.75)
                itemAppearance.selected.iconColor = tabSelectedColor.withAlphaComponent(0.9)
                itemAppearance.normal.titleTextAttributes = [.foregroundColor: tabNormalColor.withAlphaComponent(0.75)]
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: tabSelectedColor.withAlphaComponent(0.9)]
            }
        }
        if #available(iOS 26.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundEffect = nil
            tabBarAppearance.backgroundColor = UIColor(Color.pillrPrimary)
            tabBarAppearance.shadowColor = .clear
            applyBadgeColors(to: tabBarAppearance)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        } else {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = UIColor(Color.pillrPrimary)
            applyBadgeColors(to: tabBarAppearance)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Keep enabled switches consistent across the whole app.
        UISwitch.appearance().onTintColor = UIColor(Color.pillrToggleActive)
    }

    private func restoreLatestBackup() {
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
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(interactionStore)
                .environmentObject(userSettings)
                .environmentObject(storeManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Update badge when ContentView appears
                    store.checkAndResetBadge()
                    backupManager.startAutomaticBackups()
                    backupManager.backupExistingDeviceDataIfNeeded(
                        hasLocalData: !store.medications.isEmpty
                            || !store.logs.isEmpty
                            || !interactionStore.interactionHistory.isEmpty
                    )
                    if store.medications.isEmpty
                        && store.logs.isEmpty
                        && interactionStore.interactionHistory.isEmpty {
                        restoreLatestBackup()
                    }
                }
                .task {
                    // Initialize StoreKit, load products and check for purchases
                    await storeManager.loadProducts()
                    await storeManager.updatePurchasedProducts()
                }
                .alert(
                    "iCloud Drive Folder Created",
                    isPresented: Binding(
                        get: { backupManager.pendingFolderCreatedNotice },
                        set: { newValue in
                            if !newValue {
                                backupManager.dismissFolderCreatedNotice()
                            }
                        }
                    )
                ) {
                    Button("OK", role: .cancel) {
                        backupManager.dismissFolderCreatedNotice()
                    }
                } message: {
                    Text(backupManager.folderCreatedNoticeMessage)
                }
        }
    }
}

// Using the NotificationDelegate defined in NotificationManager.swift

@MainActor
final class LocalBackupManager: ObservableObject {
    static let shared = LocalBackupManager()

    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var pendingFolderCreatedNotice = false

    private var hasStartedAutomaticBackups = false
    private var backupWorkItem: DispatchWorkItem?
    private var isRestoring = false
    private let backupFileName = "pillr-latest-backup.plist"
    private let archivedBackupPrefix = "pillr-backup-"
    private let backupFolderName = "Pillr Backups"
    private let backupFolderNoticeKey = "hasShownVisibleBackupFolderNotice"
    private let existingDataMigrationKey = "hasMigratedExistingDeviceDataToVisibleBackup"
    private let archivedBackupLimit = 10
    private let meaningfulBackupKeys = [
        "medicationsData",
        "medicationLogsData",
        "interactionHistoryData"
    ]

    private init() {}

    var folderCreatedNoticeMessage: String {
        "A new folder called Pillr has been created in your iCloud Drive account. Your updated medication information and app backup will be saved there."
    }

    func startAutomaticBackups() {
        guard !hasStartedAutomaticBackups else { return }
        hasStartedAutomaticBackups = true

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isRestoring else { return }
                self.scheduleAutomaticBackup()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performBackupNow()
            }
        }

        scheduleAutomaticBackup()
    }

    func backupExistingDeviceDataIfNeeded(hasLocalData: Bool) {
        guard hasLocalData else { return }

        let backupExists = latestBackupURL(createDirectories: false).map {
            FileManager.default.fileExists(atPath: $0.path)
        } ?? false

        let alreadyMigrated = UserDefaults.standard.bool(forKey: existingDataMigrationKey)
        guard !backupExists || !alreadyMigrated else { return }

        performBackupNow()
        UserDefaults.standard.set(true, forKey: existingDataMigrationKey)
    }

    func scheduleAutomaticBackup() {
        backupWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performBackupNow()
        }
        backupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    func performBackupNow() {
        guard !isRestoring else { return }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        guard let backupURL = latestBackupURL(createDirectories: true) else { return }

        let appDomain = UserDefaults.standard.persistentDomain(forName: bundleIdentifier) ?? [:]
        let hasMeaningfulContent = appDomainHasMeaningfulContent(appDomain)
        let latestBackupExists = FileManager.default.fileExists(atPath: backupURL.path)

        if !hasMeaningfulContent && latestBackupExists {
            return
        }

        let payload: [String: Any] = [
            "createdAt": Date(),
            "bundleIdentifier": bundleIdentifier,
            "appDomain": appDomain
        ]

        guard PropertyListSerialization.propertyList(payload, isValidFor: .binary) else { return }

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
            if latestBackupExists,
               let existingData = try? Data(contentsOf: backupURL),
               existingData == data {
                return
            }
            try data.write(to: backupURL, options: .atomic)
            writeArchivedBackup(data: data)
            lastBackupDate = Date()
        } catch {
            print("Automatic backup failed: \(error)")
        }
    }

    func dismissFolderCreatedNotice() {
        pendingFolderCreatedNotice = false
    }

    func restoreLatestBackup(completion: @escaping (Bool) -> Void) {
        guard let backupURL = latestAvailableBackupURL() else {
            completion(false)
            return
        }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            completion(false)
            return
        }

        do {
            let data = try Data(contentsOf: backupURL)
            let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let payload = propertyList as? [String: Any],
                  let appDomain = payload["appDomain"] as? [String: Any] else {
                completion(false)
                return
            }

            isRestoring = true
            UserDefaults.standard.setPersistentDomain(appDomain, forName: bundleIdentifier)
            UserDefaults.standard.synchronize()
            isRestoring = false
            scheduleAutomaticBackup()
            completion(true)
        } catch {
            isRestoring = false
            print("Backup restore failed: \(error)")
            completion(false)
        }
    }

    private func latestBackupURL(createDirectories: Bool) -> URL? {
        guard let backupFolderURL = backupFolderURL(createDirectories: createDirectories) else {
            return nil
        }
        return backupFolderURL.appendingPathComponent(backupFileName)
    }

    private func backupFolderURL(createDirectories: Bool) -> URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.app.Pillr") else {
            return nil
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let backupFolderURL = documentsURL.appendingPathComponent(backupFolderName, isDirectory: true)

        if createDirectories {
            let folderAlreadyExists = FileManager.default.fileExists(atPath: backupFolderURL.path)
            try? FileManager.default.createDirectory(at: backupFolderURL, withIntermediateDirectories: true)
            if !folderAlreadyExists {
                showFolderCreatedNoticeIfNeeded()
            }
        }

        return backupFolderURL
    }

    private func latestAvailableBackupURL() -> URL? {
        guard let backupFolderURL = backupFolderURL(createDirectories: false) else { return nil }
        let fileManager = FileManager.default
        let latestBackupURL = backupFolderURL.appendingPathComponent(backupFileName)
        var urls: [URL] = []

        if fileManager.fileExists(atPath: latestBackupURL.path) {
            urls.append(latestBackupURL)
        }

        if let archivedURLs = try? fileManager.contentsOfDirectory(
            at: backupFolderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isUbiquitousItemKey],
            options: [.skipsHiddenFiles]
        ) {
            let matchingArchived = archivedURLs
                .filter {
                    let name = $0.lastPathComponent
                    return name.hasPrefix(archivedBackupPrefix) && name.hasSuffix(".plist")
                }
            urls.append(contentsOf: matchingArchived)
        }

        let datedURLs = urls.compactMap { url -> (URL, Date)? in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isUbiquitousItemKey])
            if values?.isUbiquitousItem == true {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            return (url, values?.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.1 > $1.1 }

        return datedURLs.first?.0
    }

    private func writeArchivedBackup(data: Data) {
        guard let backupFolderURL = backupFolderURL(createDirectories: true) else { return }
        let archiveURL = backupFolderURL.appendingPathComponent(archivedBackupFileName(for: Date()))
        do {
            try data.write(to: archiveURL, options: .atomic)
            pruneArchivedBackups(in: backupFolderURL)
        } catch {
            print("Archived backup failed: \(error)")
        }
    }

    private func pruneArchivedBackups(in backupFolderURL: URL) {
        guard let archivedURLs = try? FileManager.default.contentsOfDirectory(
            at: backupFolderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let oldArchivedURLs = archivedURLs
            .filter {
                let name = $0.lastPathComponent
                return name.hasPrefix(archivedBackupPrefix) && name.hasSuffix(".plist")
            }
            .sorted {
                let lhsDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .dropFirst(archivedBackupLimit)

        for url in oldArchivedURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func archivedBackupFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        return "\(archivedBackupPrefix)\(formatter.string(from: date)).plist"
    }

    private func appDomainHasMeaningfulContent(_ appDomain: [String: Any]) -> Bool {
        meaningfulBackupKeys.contains { key in
            guard let value = appDomain[key] else { return false }
            return backupValueHasMeaningfulContent(value)
        }
    }

    private func backupValueHasMeaningfulContent(_ value: Any) -> Bool {
        if let data = value as? Data {
            guard !data.isEmpty else { return false }
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                return backupJSONObjectHasMeaningfulContent(jsonObject)
            }
            return true
        }

        return backupJSONObjectHasMeaningfulContent(value)
    }

    private func backupJSONObjectHasMeaningfulContent(_ value: Any) -> Bool {
        switch value {
        case let array as [Any]:
            return !array.isEmpty
        case let dictionary as [String: Any]:
            return !dictionary.isEmpty
        case let string as String:
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func showFolderCreatedNoticeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: backupFolderNoticeKey) else { return }
        UserDefaults.standard.set(true, forKey: backupFolderNoticeKey)
        pendingFolderCreatedNotice = true
    }
}
