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
        setupNotificationActions()
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
        
        // Define the medication reminder category (group of actions)
        let category = UNNotificationCategory(
            identifier: "MEDICATION_REMINDER",
            actions: [takeAction, remindAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories (we may add more later)
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // Legacy support for single notification
    func scheduleNotification(for medication: Medication) -> UUID {
        // Don't schedule notifications for archived medications
        if medication.isArchived {
            return UUID() // Return dummy ID that won't be used
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to take your medication"
        content.body = "It's time to take \(medication.name) (\(medication.dosage))"
        content.sound = UNNotificationSound.default
        content.userInfo = ["medicationID": medication.id.uuidString]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        
        let notificationID = UUID()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: medication.timeToTake)
        let minute = calendar.component(.minute, from: medication.timeToTake)
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Check if the reminder time has already passed for today
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let timeHasPassed = (hour < currentHour || (hour == currentHour && minute <= currentMinute))
        
        if medication.isOneTimeWithFollowUp {
            // Schedule a one-time notification
            let now = Date()
            var fireDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            // Always add a day if the time has already passed for today
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
        
        // If regular notification and time has passed for today, set it to start tomorrow
        if timeHasPassed {
            // Set to start tomorrow
            dateComponents.day = calendar.component(.day, from: calendar.date(byAdding: .day, value: 1, to: now)!)
            dateComponents.month = calendar.component(.month, from: calendar.date(byAdding: .day, value: 1, to: now)!)
            dateComponents.year = calendar.component(.year, from: calendar.date(byAdding: .day, value: 1, to: now)!)
        }
        
        // Default: schedule repeating notification
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
        // Schedule the follow-up notification for 30 minutes later (premium only)
        if UserSettings.shared.isPremiumUser {
            scheduleFollowUpNotification(for: medication, after: 30, originalID: notificationID)
        }
        return notificationID
    }
    
    // New method for scheduling multiple notifications
    func scheduleMultipleNotifications(for medication: Medication) -> [UUID] {
        // Don't schedule notifications for archived medications
        if medication.isArchived {
            return [] // Return empty array
        }
        
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
        content.threadIdentifier = "medication-reminders"
        
        // Set the notification icon badge
        content.badge = 1
        
        // Extract hour and minute
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Create date components
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Check if the reminder time is earlier than the current time on the same day
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // If it's a new medication and the reminder time has already passed for today,
        // we want to start notifications from tomorrow (by setting the day component)
        if (hour < currentHour || (hour == currentHour && minute <= currentMinute)) {
            // Set to start tomorrow
            dateComponents.day = calendar.component(.day, from: calendar.date(byAdding: .day, value: 1, to: now)!)
            dateComponents.month = calendar.component(.month, from: calendar.date(byAdding: .day, value: 1, to: now)!)
            dateComponents.year = calendar.component(.year, from: calendar.date(byAdding: .day, value: 1, to: now)!)
        }
        
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
        
        // Schedule the follow-up notification for 30 minutes later (premium only)
        if UserSettings.shared.isPremiumUser {
            scheduleFollowUpNotification(for: medication, time: time, index: index, after: 30, originalID: notificationID)
        }
        
        
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
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        
        // Create a time-based trigger for the follow-up (30 minutes after scheduled time)
        let calendar = Calendar.current
        if let followUpTime = calendar.date(byAdding: .minute, value: minutes, to: time) {
            let followUpHour = calendar.component(.hour, from: followUpTime)
            let followUpMinute = calendar.component(.minute, from: followUpTime)
            
            var dateComponents = DateComponents()
            dateComponents.hour = followUpHour
            dateComponents.minute = followUpMinute
            
            // Check if the original reminder time has already passed for today
            let now = Date()
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            
            // If the original reminder has already passed for today, 
            // schedule the follow-up to start tomorrow as well
            if (hour < currentHour || (hour == currentHour && minute <= currentMinute)) {
                // Set to start tomorrow
                dateComponents.day = calendar.component(.day, from: calendar.date(byAdding: .day, value: 1, to: now)!)
                dateComponents.month = calendar.component(.month, from: calendar.date(byAdding: .day, value: 1, to: now)!)
                dateComponents.year = calendar.component(.year, from: calendar.date(byAdding: .day, value: 1, to: now)!)
            }
            
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
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        
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
    
    // MARK: - Focus session helpers
    
    func scheduleFocusSession(start: Date, durationMinutes: Int) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        
        // Start notification
        let startContent = UNMutableNotificationContent()
        startContent.title = "Focus session starting"
        startContent.body = "Use this window for your most important tasks."
        startContent.sound = UNNotificationSound.default
        startContent.threadIdentifier = "focus-session"
        
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        let startTrigger = UNCalendarNotificationTrigger(dateMatching: startComponents, repeats: false)
        let startRequest = UNNotificationRequest(identifier: UUID().uuidString, content: startContent, trigger: startTrigger)
        center.add(startRequest) { error in
            if let error = error {
                print("Error scheduling focus session start: \(error.localizedDescription)")
            }
        }
        
        // Mid-session gentle check-in (if long enough)
        if durationMinutes >= 40 {
            let midDate = start.addingTimeInterval(TimeInterval((durationMinutes / 2) * 60))
            let midContent = UNMutableNotificationContent()
            midContent.title = "Halfway through your focus session"
            midContent.body = "Quick stretch, sip of water, or refocus if needed."
            midContent.sound = UNNotificationSound.default
            midContent.threadIdentifier = "focus-session"
            
            let midComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: midDate)
            let midTrigger = UNCalendarNotificationTrigger(dateMatching: midComponents, repeats: false)
            let midRequest = UNNotificationRequest(identifier: UUID().uuidString, content: midContent, trigger: midTrigger)
            center.add(midRequest) { error in
                if let error = error {
                    print("Error scheduling focus session mid-point: \(error.localizedDescription)")
                }
            }
        }
        
        // End notification
        let endDate = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let endContent = UNMutableNotificationContent()
        endContent.title = "Focus session ending"
        endContent.body = "Time to wrap up or switch to lighter tasks."
        endContent.sound = UNNotificationSound.default
        endContent.threadIdentifier = "focus-session"
        
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: endDate)
        let endTrigger = UNCalendarNotificationTrigger(dateMatching: endComponents, repeats: false)
        let endRequest = UNNotificationRequest(identifier: UUID().uuidString, content: endContent, trigger: endTrigger)
        center.add(endRequest) { error in
            if let error = error {
                print("Error scheduling focus session end: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(with id: UUID) {
        let baseID = id.uuidString
        // Cancel the primary, follow-up, and stimulant phase notifications derived from this ID
        let identifiers = [
            baseID,
            "\(baseID)_followup",
            "\(baseID)_onset",
            "\(baseID)_fade"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelMultipleNotifications(ids: [UUID]) {
        for id in ids {
            cancelNotification(with: id)
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        resetApplicationBadge()
    }
    
    // Function to reset the application badge to zero
    func resetApplicationBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Error resetting badge count: \(error.localizedDescription)")
            }
        }
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
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        
        // Since baseInterval already accounts for whether the original notification
        // was scheduled for today or tomorrow, we just add the follow-up delay
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
    
    // MARK: - Stimulant phase notifications

    private func shouldScheduleStimulantTiming(for medication: Medication) -> Bool {
        return medication.hasStimulantTiming
    }

    func scheduleStimulantPhaseNotifications(for medication: Medication, doseTime: Date) {
        guard shouldScheduleStimulantTiming(for: medication),
              let onset = medication.onsetMinutes,
              let duration = medication.durationMinutes else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let now = Date()
        let calendar = Calendar.current

        func scheduleNotification(title: String, body: String, userInfo: [String: Any], identifierSuffix: String, fireDate: Date) {
            let interval = fireDate.timeIntervalSince(now)
            guard interval > 0 else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            content.userInfo = userInfo
            content.categoryIdentifier = "MEDICATION_REMINDER"
            content.threadIdentifier = "medication-reminders"
            content.badge = 1

            let request = UNNotificationRequest(
                identifier: "\(medication.id.uuidString)_\(identifierSuffix)_\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )

            center.add(request) { error in
                if let error = error {
                    print("Error scheduling \(identifierSuffix) stimulant notification: \(error.localizedDescription)")
                }
            }
        }

        if let onsetDate = calendar.date(byAdding: .minute, value: onset, to: doseTime) {
            scheduleNotification(
                title: "Medication starting to work",
                body: "\(medication.name) is likely starting to work. This can be a good time to ease into tasks or planning.",
                userInfo: [
                    "medicationID": medication.id.uuidString,
                    "phase": "onset"
                ],
                identifierSuffix: "onset",
                fireDate: onsetDate
            )
        }

        if let fadeDate = calendar.date(byAdding: .minute, value: duration, to: doseTime) {
            let (fadeTitle, fadeBody) = medication.enableDailyCheckIn
                ? ("Daily check-in for \(medication.name)",
                   "How was your focus and side effects today? Take a moment to log a quick check-in.")
                : ("Medication may wear off soon",
                   "\(medication.name) is likely wearing off. This can be a good time for a break, snack, or lighter tasks.")

            scheduleNotification(
                title: fadeTitle,
                body: fadeBody,
                userInfo: [
                    "medicationID": medication.id.uuidString,
                    "phase": "fade",
                    "isDailyCheckIn": medication.enableDailyCheckIn
                ],
                identifierSuffix: "fade",
                fireDate: fadeDate
            )
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
                    // Log the medication as taken (without additional check-in metadata)
                    MedicationStore.shared.logMedicationTaken(
                        medication: medication,
                        actualTime: Date(),
                        notes: nil
                    )
                    
                    // Provide success haptic feedback
                    HapticManager.shared.successNotification()
                    
                    // Reset badge count after action
                    NotificationManager.shared.resetApplicationBadge()
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
            // User tapped the notification itself.
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString),
               let medication = MedicationStore.shared.findMedication(with: medicationID) {
                
                // If this is a stimulant fade notification with daily check-in enabled,
                // surface the notes & side-effects logging sheet for this medication.
                if let phase = userInfo["phase"] as? String,
                   phase == "fade",
                   medication.enableDailyCheckIn {
                    DispatchQueue.main.async {
                        MedicationStore.shared.dailyCheckInMedication = medication
                    }
                }
                
                // Always reset badge count after tapping a medication notification.
                NotificationManager.shared.resetApplicationBadge()
            } else {
                // Fallback: still reset badge.
                NotificationManager.shared.resetApplicationBadge()
            }
        }
        
        completionHandler()
    }
} 
