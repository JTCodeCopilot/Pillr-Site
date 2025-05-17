import SwiftUI
import UserNotifications

@main
struct MedLogAppApp: App { // Replace MedLogAppApp with your app's name
    @StateObject var store = MedicationStore()
    @StateObject var interactionStore = InteractionStore.shared
    @StateObject var openAIService = OpenAIService.shared
    @StateObject var userSettings = UserSettings.shared
    @State private var showNamePrompt = false
    
    init() {
        // Request notification permission on app launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        // Set notification delegate to handle user responses
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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
