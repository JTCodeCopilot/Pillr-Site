//
//  NotificationManager.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
        setupNotificationActions()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupNotificationActions() {
        // Define the actions
        let takeAction = UNNotificationAction(
            identifier: "TAKE_ACTION",
            title: "Take Now",
            options: .foreground
        )
        
        let remindAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind in 5 minutes",
            options: .foreground
        )
        
        // Define the category (group of actions)
        let category = UNNotificationCategory(
            identifier: "MEDICATION_REMINDER",
            actions: [takeAction, remindAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // Legacy support for single notification
    func scheduleNotification(for medication: Medication) -> UUID {
        let content = UNMutableNotificationContent()
        content.title = "Time to take your medication"
        content.body = "It's time to take \(medication.name) (\(medication.dosage))"
        content.sound = UNNotificationSound.default
        content.userInfo = ["medicationID": medication.id.uuidString]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        let notificationID = UUID()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: medication.timeToTake)
        let minute = calendar.component(.minute, from: medication.timeToTake)
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        if medication.isOneTimeWithFollowUp {
            // Schedule a one-time notification
            let now = Date()
            var fireDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            if fireDate < now { fireDate = Calendar.current.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate }
            let interval = fireDate.timeIntervalSince(now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: notificationID.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling one-time notification: \(error.localizedDescription)")
                }
            }
            // Schedule a one-time follow up 30 minutes later
            scheduleOneTimeFollowUp(for: medication, after: 30, originalID: notificationID, baseInterval: interval)
            return notificationID
        }
        // Default: schedule repeating notification
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
        // Schedule the follow-up notification for 30 minutes later
        scheduleFollowUpNotification(for: medication, after: 30, originalID: notificationID)
        return notificationID
    }
    
    // New method for scheduling multiple notifications
    func scheduleMultipleNotifications(for medication: Medication) -> [UUID] {
        var notificationIDs: [UUID] = []
        
        // Use reminderTimes if available, otherwise fall back to legacy timeToTake
        let times = medication.reminderTimes.isEmpty ? [medication.timeToTake] : medication.reminderTimes
        
        for (index, reminderTime) in times.enumerated() {
            let notificationID = scheduleNotificationForTime(
                medication: medication,
                time: reminderTime,
                index: index,
                total: times.count
            )
            notificationIDs.append(notificationID)
        }
        
        return notificationIDs
    }
    
    private func scheduleNotificationForTime(medication: Medication, time: Date, index: Int, total: Int) -> UUID {
        let content = UNMutableNotificationContent()
        
        // Customize the notification based on which reminder it is
        if total > 1 {
            let doseNumber = index + 1
            content.title = "Time for dose #\(doseNumber) of \(medication.name)"
            content.body = "Take \(medication.pillsPerDose) \(medication.dosage) (\(formatTimeOnly(time)))"
        } else {
            content.title = "Time to take your medication"
            content.body = "It's time to take \(medication.name) (\(medication.dosage))"
        }
        
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "medicationID": medication.id.uuidString,
            "reminderIndex": index
        ]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        // Extract hour and minute
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Create date components
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Create the trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the notification request with a unique identifier
        let notificationID = UUID()
        let request = UNNotificationRequest(identifier: notificationID.uuidString, content: content, trigger: trigger)
        
        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
        
        // Schedule the follow-up notification for 30 minutes later
        scheduleFollowUpNotification(for: medication, time: time, index: index, after: 30, originalID: notificationID)
        
        return notificationID
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    func scheduleFollowUpNotification(for medication: Medication, after minutes: Int, originalID: UUID) {
        scheduleFollowUpNotification(for: medication, time: medication.timeToTake, index: 0, after: minutes, originalID: originalID)
    }
    
    func scheduleFollowUpNotification(for medication: Medication, time: Date, index: Int, after minutes: Int, originalID: UUID) {
        let content = UNMutableNotificationContent()
        
        if medication.reminderTimes.count > 1 {
            let doseNumber = index + 1
            content.title = "Reminder: Dose #\(doseNumber) Due"
            content.body = "Don't forget to take your \(medication.name) dose #\(doseNumber)"
        } else {
            content.title = "Reminder: Medication Due"
            content.body = "Don't forget to take your \(medication.name)"
        }
        
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "medicationID": medication.id.uuidString,
            "isFollowUp": true,
            "originalNotificationID": originalID.uuidString,
            "reminderIndex": index
        ]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        // Create a time-based trigger for the follow-up (30 minutes after scheduled time)
        let calendar = Calendar.current
        if let followUpTime = calendar.date(byAdding: .minute, value: minutes, to: time) {
            let followUpHour = calendar.component(.hour, from: followUpTime)
            let followUpMinute = calendar.component(.minute, from: followUpTime)
            
            var dateComponents = DateComponents()
            dateComponents.hour = followUpHour
            dateComponents.minute = followUpMinute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // Create a unique ID for the follow-up by adding a suffix
            let followUpID = "\(originalID.uuidString)_followup"
            let request = UNNotificationRequest(identifier: followUpID, content: content, trigger: trigger)
            
            // Add the follow-up notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling follow-up notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func scheduleOneTimeReminder(for medication: Medication, afterMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder: Take Your Medication"
        content.body = "It's time to take \(medication.name) (\(medication.dosage))"
        content.sound = UNNotificationSound.default
        content.userInfo = ["medicationID": medication.id.uuidString]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        // Create a time-based trigger for one-time reminder
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(afterMinutes * 60), repeats: false)
        
        // Generate a unique ID for this one-time reminder
        let reminderID = UUID().uuidString
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        
        // Add the reminder notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling one-time reminder: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(with id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        // Also cancel the follow-up notification if it exists
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(id.uuidString)_followup"])
    }
    
    func cancelMultipleNotifications(ids: [UUID]) {
        for id in ids {
            cancelNotification(with: id)
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // Add a new function for one-time follow up
    private func scheduleOneTimeFollowUp(for medication: Medication, after minutes: Int, originalID: UUID, baseInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder: Medication Due"
        content.body = "Don't forget to take your \(medication.name)"
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "medicationID": medication.id.uuidString,
            "isFollowUp": true,
            "originalNotificationID": originalID.uuidString,
            "reminderIndex": 0
        ]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        let followUpInterval = baseInterval + Double(minutes * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: followUpInterval, repeats: false)
        let followUpID = "\(originalID.uuidString)_followup"
        let request = UNNotificationRequest(identifier: followUpID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling one-time follow-up notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Notification Feedback Manager

class NotificationFeedbackManager {
    static let shared = NotificationFeedbackManager()
    
    private init() {}
    
    func triggerNotificationHaptic() {
        // Always provide haptic feedback for medication reminders
        // Use a rigidImpact followed by success notification for a distinctive pattern
        DispatchQueue.main.async {
            HapticManager.shared.rigidImpact()
            
            // Small delay between haptics feels more intentional
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.shared.successNotification()
            }
        }
    }
    
    func triggerReminderHaptic() {
        // For follow-up reminders, use a slightly different pattern
        DispatchQueue.main.async {
            HapticManager.shared.mediumImpact()
            
            // Small delay between haptics
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                HapticManager.shared.mediumImpact()
            }
            
            // Final success notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HapticManager.shared.successNotification()
            }
        }
    }
}

// MARK: - Notification Delegate
// This delegate will handle notification responses and trigger appropriate haptics

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Called when a notification is delivered to a foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Check if the notification is a medication reminder
        if notification.request.content.categoryIdentifier == "MEDICATION_REMINDER" {
            // Check if it's a follow-up reminder
            if let isFollowUp = notification.request.content.userInfo["isFollowUp"] as? Bool, isFollowUp {
                NotificationFeedbackManager.shared.triggerReminderHaptic()
            } else {
                NotificationFeedbackManager.shared.triggerNotificationHaptic()
            }
        }
        
        // Allow the notification to present with sound, banner, and list
        completionHandler([.sound, .banner, .list])
    }
    
    // Called when a user responds to a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // Handle different notification actions
        switch response.actionIdentifier {
        case "TAKE_ACTION":
            // User tapped "Take Now" - log the medication as taken
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString) {
                
                // Find the medication and log it as taken
                if let medication = MedicationStore.shared.findMedication(with: medicationID) {
                    // Log the medication as taken
                    MedicationStore.shared.logMedicationTaken(medication: medication, actualTime: Date(), notes: nil)
                    
                    // Provide success haptic feedback
                    HapticManager.shared.successNotification()
                }
            }
            
        case "REMIND_LATER":
            // User tapped "Remind Later" - schedule a reminder in 5 minutes
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString) {
                
                // Find the medication
                if let medication = MedicationStore.shared.findMedication(with: medicationID) {
                    // Schedule a one-time reminder for 5 minutes later
                    NotificationManager.shared.scheduleOneTimeReminder(for: medication, afterMinutes: 5)
                    
                    // Provide light haptic feedback
                    HapticManager.shared.lightImpact()
                }
            }
            
        default:
            // User tapped the notification itself - no specific action
            break
        }
        
        completionHandler()
    }
} 