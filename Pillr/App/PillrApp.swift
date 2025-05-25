//
//  PillrApp.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI
import UserNotifications

@main
struct PillrApp: App {
    @StateObject private var store = MedicationStore.shared
    @StateObject private var interactionStore = InteractionStore.shared

    @StateObject private var userSettings = UserSettings.shared
    
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
        
        // Request notification permission on app launch - skip in preview mode
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            // requestNotificationPermission() // Removed to request contextually
        }
        #else
        // requestNotificationPermission() // Removed to request contextually
        #endif
        
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    // private func requestNotificationPermission() { ... } // This function can be removed or kept if used elsewhere,
    // For now, I will comment it out as it is not called from anywhere else.
    /*
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    */
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(interactionStore)

                .environmentObject(userSettings)
                .preferredColorScheme(.dark)
        }
    }
}

// Using the NotificationDelegate defined in NotificationManager.swift

