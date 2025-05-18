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
    @StateObject private var openAIService = OpenAIService.shared
    @StateObject private var userSettings = UserSettings.shared
    @State private var showNamePrompt = false
    
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
            requestNotificationPermission()
        }
        #else
        requestNotificationPermission()
        #endif
        
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(interactionStore)
                    .environmentObject(openAIService)
                    .environmentObject(userSettings)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // Check if we need to show the name prompt
                        showNamePrompt = userSettings.isFirstLaunch
                    }
                
                if showNamePrompt {
                    UserNameInputView(isShowing: $showNamePrompt)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showNamePrompt)
        }
    }
}

// Using the NotificationDelegate defined in NotificationManager.swift

