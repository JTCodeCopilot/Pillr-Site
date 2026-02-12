//
//  PillrApp.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI
import UserNotifications
import BackgroundTasks
import TelemetryDeck
import TikTokBusinessSDK

// App Delegate to handle application lifecycle events
final class PillrAppDelegate: NSObject, UIApplicationDelegate {
    private let cloudSyncRefreshTaskID = "com.pillr.cloud-sync-refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        application.registerForRemoteNotifications()
        registerBackgroundTasks()
        scheduleCloudSyncRefresh()
        Task { @MainActor in
            if UserSettings.shared.shouldUseCloudSync {
                CloudKitMedicationSync.shared.ensureSubscriptions()
            }
        }
        
        let config = TikTokConfig(
            appId: "6746717689",
            tiktokAppId: "7593781364499988488"
        
        )
        TikTokBusiness.initializeSdk(config) { _, error in
            if let error = error {
                print("TikTok SDK init error: \(error)")
            }
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleCloudSyncRefresh()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Update badge and refresh CloudKit whenever the app is active.
        // This covers both cold start and return-from-background.
        Task { @MainActor in
            MedicationStore.shared.checkAndResetBadge()
            MedicationStore.shared.refreshCloudSyncIfNeeded { _ in
                MedicationStore.shared.loadMedications()
                MedicationStore.shared.loadLogs()
                MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date())
                MedicationStore.shared.reconcileNotificationSchedules(referenceDate: Date())
            }
            MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date())
            NotificationManager.shared.surfaceDeliveredStimulantCheckInsIfNeeded()
            incrementAppLaunchCountIfNeeded()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Foreground-specific work is handled in applicationDidBecomeActive.
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        CloudKitMedicationSync.shared.handleRemoteNotification(userInfo) { result in
            Task { @MainActor in
                guard result == .newData else {
                    completionHandler(result)
                    return
                }
                MedicationStore.shared.refreshCloudSyncIfNeeded { fetchResult in
                    MedicationStore.shared.reconcileNotificationSchedules(referenceDate: Date())
                    completionHandler(fetchResult == .failed ? .failed : .newData)
                }
            }
        }
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

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: cloudSyncRefreshTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleCloudSyncRefresh(task: refreshTask)
        }
    }

    private func scheduleCloudSyncRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: cloudSyncRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Unable to schedule cloud sync refresh: \(error)")
        }
    }

    private func handleCloudSyncRefresh(task: BGAppRefreshTask) {
        scheduleCloudSyncRefresh()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation {
            let semaphore = DispatchSemaphore(value: 0)
            Task { @MainActor in
                MedicationStore.shared.refreshCloudSyncIfNeeded { _ in
                    MedicationStore.shared.reconcileNotificationSchedules(referenceDate: Date())
                    semaphore.signal()
                }
            }
            _ = semaphore.wait(timeout: .now() + 20)
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        queue.addOperation(operation)
    }
}

@main
struct PillrApp: App {
    // IMPORTANT: Medication data stays on-device and mirrors to iCloud for backup.
    // Data is only removed when the app is completely uninstalled.
    
    @UIApplicationDelegateAdaptor private var appDelegate: PillrAppDelegate
    
    @StateObject private var store = MedicationStore.shared
    @StateObject private var interactionStore = InteractionStore.shared
    @StateObject private var userSettings = UserSettings.shared
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var appTheme = AppTheme.shared
    
    init() {
        // Set preview environment detection
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Prevent UserDefaults persistence during previews/tests
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            
            // Set flag for previews to optimize rendering speed
            UserDefaults.standard.set(true, forKey: "isRunningPreview")
            
            // Use simplified data models for previews to speed up build time
            UserDefaults.standard.set(true, forKey: "useMinimalDataForPreviews")
            
            // Disable animations in preview mode for faster rendering
            UIView.setAnimationsEnabled(false)
        } else {
            // Clear the preview flag so normal runs aren't treated as previews.
            UserDefaults.standard.set(false, forKey: "isRunningPreview")
        }
        #endif
        
        // Application appearance settings
        configureAppAppearance(for: AppTheme.shared.mode)
        // Initialize TelemetryDeck analytics
        let telemetryConfig = TelemetryDeck.Config(appID: "1AEFCFCE-EC76-475D-A16E-8AC2A28ECF82")
        TelemetryDeck.initialize(config: telemetryConfig)
    }
    
    private func configureAppAppearance(for mode: AppThemeMode) {
        let palette: AppThemePalette
        switch mode {
        case .light:
            palette = .light
        case .dark:
            palette = .dark
        case .system:
            palette = AppTheme.shared.systemColorScheme == .dark ? .dark : .light
        }
        let navigationTitleColor = UIColor(hexLiteral: palette.navigationTitle)
        let navigationBackgroundColor = UIColor(hexLiteral: palette.navigationBackground)
        let tabBarBackgroundColor = UIColor(hexLiteral: palette.tabBarBackground)
        let tabBarSelectedItemColor = UIColor(hexLiteral: AppThemePalette.light.textPrimary)
        let tabBarUnselectedItemColor = UIColor(hexLiteral: AppThemePalette.light.textPrimary)
        let overdueBadgeColor = UIColor(hexLiteral: palette.warning)
        let segmentedBackgroundColor = UIColor(hexLiteral: palette.surfaceSecondary)
        let segmentedSelectedColor = UIColor(hexLiteral: palette.buttonPrimaryBackground)
        let segmentedNormalTextColor = UIColor(hexLiteral: palette.textPrimary)
        let segmentedSelectedTextColor = UIColor(hexLiteral: palette.buttonPrimaryForeground)

        // Configure navigation bar appearance
        if #available(iOS 26.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: navigationTitleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: navigationTitleColor]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        } else {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = navigationBackgroundColor
            appearance.titleTextAttributes = [.foregroundColor: navigationTitleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: navigationTitleColor]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        UINavigationBar.appearance().tintColor = navigationTitleColor
        
        // Configure tab bar appearance
        func applyBadgeColors(to appearance: UITabBarAppearance) {
            let itemAppearances = [
                appearance.stackedLayoutAppearance,
                appearance.inlineLayoutAppearance,
                appearance.compactInlineLayoutAppearance
            ]
            for itemAppearance in itemAppearances {
                itemAppearance.normal.iconColor = tabBarUnselectedItemColor
                itemAppearance.normal.titleTextAttributes = [.foregroundColor: tabBarUnselectedItemColor]
                itemAppearance.selected.iconColor = tabBarSelectedItemColor
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: tabBarSelectedItemColor]
                itemAppearance.normal.badgeBackgroundColor = overdueBadgeColor
                itemAppearance.selected.badgeBackgroundColor = overdueBadgeColor
                itemAppearance.normal.badgeTextAttributes = [.foregroundColor: UIColor.white]
                itemAppearance.selected.badgeTextAttributes = [.foregroundColor: UIColor.white]
            }
        }
        if #available(iOS 26.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundEffect = nil
            tabBarAppearance.backgroundColor = tabBarBackgroundColor
            tabBarAppearance.shadowColor = .clear
            applyBadgeColors(to: tabBarAppearance)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        } else {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = tabBarBackgroundColor
            applyBadgeColors(to: tabBarAppearance)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        }
        UITabBar.appearance().tintColor = tabBarSelectedItemColor
        UITabBar.appearance().unselectedItemTintColor = tabBarUnselectedItemColor
        UITabBar.appearance().overrideUserInterfaceStyle = .dark

        // Configure segmented controls for readability in both themes.
        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.backgroundColor = segmentedBackgroundColor
        segmentedAppearance.selectedSegmentTintColor = segmentedSelectedColor
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: segmentedNormalTextColor],
            for: .normal
        )
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: segmentedSelectedTextColor],
            for: .selected
        )
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(interactionStore)
                .environmentObject(userSettings)
                .environmentObject(storeManager)
                .environmentObject(appTheme)
                .environment(\.pillrThemeMode, appTheme.mode)
                .preferredColorScheme(appTheme.preferredColorScheme)
                .onAppear {
                    configureAppAppearance(for: appTheme.mode)
                    // Update badge when ContentView appears
                    store.checkAndResetBadge()
                }
                .onChange(of: appTheme.mode) { _, newMode in
                    configureAppAppearance(for: newMode)
                }
                .onChange(of: appTheme.systemColorScheme) { _, _ in
                    guard appTheme.mode == .system else { return }
                    configureAppAppearance(for: .system)
                }
                .task {
                    // Initialize StoreKit, load products and check for purchases
                    await storeManager.loadProducts()
                    await storeManager.updatePurchasedProducts()
                }
        }
    }
}

// Using the NotificationDelegate defined in NotificationManager.swift
