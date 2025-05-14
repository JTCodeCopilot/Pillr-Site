import SwiftUI
import UserNotifications

@main
struct MedLogAppApp: App { // Replace MedLogAppApp with your app's name
    @StateObject var store = MedicationStore()
    
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
            ContentView()
                .environmentObject(store)
        }
    }
}

// Notification delegate to handle user interactions with notifications
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Present notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification response
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Get the medication ID from the notification
        guard let medicationIDString = userInfo["medicationID"] as? String,
              let medicationID = UUID(uuidString: medicationIDString) else {
            completionHandler()
            return
        }
        
        // Get a reference to the medication store
        let store = MedicationStore.shared
        
        switch response.actionIdentifier {
        case "TAKE_ACTION":
            // Find the medication and log it as taken
            if let medication = store.findMedication(with: medicationID) {
                store.logMedicationTaken(medication: medication, actualTime: Date(), notes: nil)
                
                // If this was a follow-up notification, cancel it
                if let isFollowUp = userInfo["isFollowUp"] as? Bool, isFollowUp,
                   let originalIDString = userInfo["originalNotificationID"] as? String,
                   let originalID = UUID(uuidString: originalIDString) {
                    NotificationManager.shared.cancelNotification(with: originalID)
                }
            }
            
        case "REMIND_LATER":
            // Schedule a one-time reminder for 5 minutes later
            if let medication = store.findMedication(with: medicationID) {
                NotificationManager.shared.scheduleOneTimeReminder(for: medication, afterMinutes: 5)
            }
            
        default:
            // Default action (notification was tapped without specific action)
            break
        }
        
        completionHandler()
    }
}
