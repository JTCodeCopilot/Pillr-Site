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
class PillrAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Reset badge on launch
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Reset badge when app becomes active
        MedicationStore.shared.checkAndResetBadge()
        NotificationManager.shared.surfaceDeliveredStimulantCheckInsIfNeeded()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Refresh data when returning to foreground
        MedicationStore.shared.loadMedications()
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
        if CommandLine.arguments.contains("--uitesting") || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Prevent UserDefaults persistence during previews/tests
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            
            // Set flag for previews to optimize rendering speed
            UserDefaults.standard.set(true, forKey: "isRunningPreview")
            
            // Use simplified data models for previews to speed up build time
            UserDefaults.standard.set(true, forKey: "useMinimalDataForPreviews")
            
            // Disable animations in preview mode for faster rendering
            UIView.setAnimationsEnabled(false)
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
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        } else {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(Color(hex: "#404C42"))
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#C7C7BD"))]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#C7C7BD"))]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Configure tab bar appearance
        if #available(iOS 26.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundEffect = nil
            tabBarAppearance.backgroundColor = .clear
            tabBarAppearance.shadowColor = .clear
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        } else {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = UIColor(Color(hex: "#404C42"))
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
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
                    // Reset badge when ContentView appears
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
