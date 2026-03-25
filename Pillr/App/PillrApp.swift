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

// App Delegate to handle application lifecycle events
final class PillrAppDelegate: NSObject, UIApplicationDelegate {
    private let cloudSyncRefreshTaskID = "com.pillr.cloud-sync-refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        registerForRemoteNotificationsIfEligible(application)
        registerBackgroundTasks()
        scheduleCloudSyncRefresh()
        Task { @MainActor in
            if UserSettings.shared.shouldUseCloudSync {
                CloudKitMedicationSync.shared.ensureSubscriptions()
            }
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleCloudSyncRefresh()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        registerForRemoteNotificationsIfEligible(application)

        // Update badge and refresh CloudKit whenever the app is active.
        // This covers both cold start and return-from-background.
        Task { @MainActor in
            MedicationStore.shared.checkAndResetBadge()
            MedicationStore.shared.refreshCloudSyncIfNeeded { _ in
                MedicationStore.shared.loadMedications()
                MedicationStore.shared.loadLogs()
                MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
            }
            MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
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
                    MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
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

    private func registerForRemoteNotificationsIfEligible(_ application: UIApplication) {
        guard UserSettings.shared.hasCompletedAppOnboarding else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAllowed: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAllowed = true
            default:
                isAllowed = false
            }
            guard isAllowed else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
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
                    MedicationStore.shared.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
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
        let overdueBadgeColor = UIColor(Color(hex: "#FFB74D"))
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
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        } else {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = UIColor(Color.pillrPrimary)
            applyBadgeColors(to: tabBarAppearance)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        }

        // Keep enabled switches consistent across the whole app.
        UISwitch.appearance().onTintColor = UIColor(Color.pillrToggleActive)
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
