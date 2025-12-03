//
//  NotificationManager.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import Foundation
import UserNotifications
import SwiftUI

fileprivate struct NotificationCategoryIdentifier {
    static let medicationReminder = "MEDICATION_REMINDER"
    static let stimulantReminder = "STIMULANT_PHASE_REMINDER"
}

fileprivate struct NotificationActionIdentifier {
    static let takeNow = "TAKE_ACTION"
    static let remindLater = "REMIND_LATER"
    static let dismiss = "DISMISS_NOTIFICATION"
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        setupNotificationActions()
    }
    
    private func setupNotificationActions() {
        // Define the actions
        let takeAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.takeNow,
            title: "Take Now",
            options: .foreground
        )
        
        let remindAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.remindLater,
            title: "Remind in 5 minutes",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.dismiss,
            title: "Dismiss",
            options: .destructive
        )
        
        // Define the medication reminder category (group of actions)
        let medicationCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.medicationReminder,
            actions: [takeAction, remindAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let stimulantCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.stimulantReminder,
            actions: [dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register all relevant notification categories
        UNUserNotificationCenter.current().setNotificationCategories([
            medicationCategory,
            stimulantCategory
        ])
    }

    private func prioritizeMedicationReminder(_ content: UNMutableNotificationContent) {
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
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
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        prioritizeMedicationReminder(content)
        
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
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        
        // Set the notification icon badge
        content.badge = 1
        prioritizeMedicationReminder(content)
        
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
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        prioritizeMedicationReminder(content)
        
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
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        prioritizeMedicationReminder(content)
        
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

    /// Cancels any pending or delivered notifications that reference the provided medication ID.
    /// This is used as a safety net for archived/deleted medications where we no longer want reminders firing.
    func cancelNotifications(forMedicationID medicationID: UUID) {
        let center = UNUserNotificationCenter.current()
        let medicationIDString = medicationID.uuidString
        let refillPrefix = "refill-\(medicationIDString)"

        center.getPendingNotificationRequests { requests in
            let identifiers = requests.compactMap { request -> String? in
                if let pendingMedicationID = request.content.userInfo["medicationID"] as? String,
                   pendingMedicationID == medicationIDString {
                    return request.identifier
                }

                if request.identifier.hasPrefix(refillPrefix) {
                    return request.identifier
                }

                return nil
            }

            if !identifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }

        center.getDeliveredNotifications { notifications in
            let identifiers = notifications.compactMap { notification -> String? in
                if let deliveredMedicationID = notification.request.content.userInfo["medicationID"] as? String,
                   deliveredMedicationID == medicationIDString {
                    return notification.request.identifier
                }

                if notification.request.identifier.hasPrefix(refillPrefix) {
                    return notification.request.identifier
                }

                return nil
            }

            if !identifiers.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        resetApplicationBadge()
    }

    /// Removes any pending/delivered medication reminder notifications that don't belong to the provided set of active medications.
    /// Useful on app launch to clear reminders for medications that were deleted or archived while the app was not running.
    func purgeNotifications(excluding validMedicationIDs: Set<UUID>) {
        let center = UNUserNotificationCenter.current()
        let validIDStrings = Set(validMedicationIDs.map { $0.uuidString })
        let refillPrefix = "refill-"

        center.getPendingNotificationRequests { requests in
            let identifiers = requests.compactMap { request -> String? in
                if let medicationID = request.content.userInfo["medicationID"] as? String {
                    return validIDStrings.contains(medicationID) ? nil : request.identifier
                }

                if request.identifier.hasPrefix(refillPrefix) {
                    let suffix = String(request.identifier.dropFirst(refillPrefix.count))
                    return validIDStrings.contains(suffix) ? nil : request.identifier
                }

                return nil
            }

            if !identifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }

        center.getDeliveredNotifications { notifications in
            let identifiers = notifications.compactMap { notification -> String? in
                if let medicationID = notification.request.content.userInfo["medicationID"] as? String {
                    return validIDStrings.contains(medicationID) ? nil : notification.request.identifier
                }

                if notification.request.identifier.hasPrefix(refillPrefix) {
                    let suffix = String(notification.request.identifier.dropFirst(refillPrefix.count))
                    return validIDStrings.contains(suffix) ? nil : notification.request.identifier
                }

                return nil
            }

            if !identifiers.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
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
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        content.badge = 1
        prioritizeMedicationReminder(content)

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
        return medication.hasStimulantTiming && medication.enableStimulantPhaseNotifications
    }

    func scheduleStimulantPhaseNotifications(for medication: Medication, doseTime: Date) {
        guard shouldScheduleStimulantTiming(for: medication),
              let onset = medication.onsetMinutes,
              let duration = medication.durationMinutes else {
            return
        }

        let calendar = Calendar.current

        if let onsetDate = calendar.date(byAdding: .minute, value: onset, to: doseTime) {
            scheduleNotification(
                for: medication,
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

        // Warn roughly 10 minutes before the expected fade so the user can prepare.
        let warningOffset = duration > 10 ? duration - 10 : duration
        if let fadeWarningDate = calendar.date(byAdding: .minute, value: warningOffset, to: doseTime) {
            let usesAutomaticCheckIn = medication.enableDailyCheckIn && medication.dailyCheckInTime == nil
            let (fadeTitle, fadeBody) = usesAutomaticCheckIn
                ? ("Check in before \(medication.name) fades",
                   "How was your focus and side effects today? Log a quick check-in before it wears off.")
                : ("\(medication.name) about to wear off",
                   "Effects may taper in ~10 minutes. Ease into lighter tasks or plan a break.")

            scheduleNotification(
                for: medication,
                title: fadeTitle,
                body: fadeBody,
                userInfo: [
                    "medicationID": medication.id.uuidString,
                    "phase": "fade",
                    "isDailyCheckIn": usesAutomaticCheckIn
                ],
                identifierSuffix: "fade",
                fireDate: fadeWarningDate
            )
        }

    }

    private func scheduleNotification(
        for medication: Medication,
        title: String,
        body: String,
        userInfo: [String: Any],
        identifierSuffix: String,
        fireDate: Date,
        category: String = NotificationCategoryIdentifier.stimulantReminder
    ) {
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.userInfo = userInfo
        content.categoryIdentifier = category
        content.threadIdentifier = "medication-reminders"
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: "\(medication.id.uuidString)_\(identifierSuffix)_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling \(identifierSuffix) notification: \(error.localizedDescription)")
            }
        }
    }

    func scheduleDailyCheckInReminder(for medication: Medication, referenceDate: Date) {
        guard medication.enableDailyCheckIn,
              let customCheckInTime = medication.dailyCheckInTime else {
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let checkInComponents = calendar.dateComponents([.hour, .minute], from: customCheckInTime)

        guard let hour = checkInComponents.hour,
              let minute = checkInComponents.minute,
              var fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) else {
            return
        }

        if fireDate <= now {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let noteBody = medication.medicationType == .stimulant
            ? "Take a moment to reflect on focus and side effects today."
            : "Add a quick note about how this medication felt today."

        scheduleNotification(
            for: medication,
            title: "Daily check-in for \(medication.name)",
            body: noteBody,
            userInfo: [
                "medicationID": medication.id.uuidString,
                "phase": "checkin",
                "isDailyCheckIn": true
            ],
            identifierSuffix: "checkin",
            fireDate: fireDate
        )
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
        
        let hapticCategories: Set<String> = [
            NotificationCategoryIdentifier.medicationReminder,
            NotificationCategoryIdentifier.stimulantReminder
        ]

        if hapticCategories.contains(notification.request.content.categoryIdentifier) {
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
        case NotificationActionIdentifier.takeNow:
            // User tapped "Take Now" - log the medication as taken
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString) {
                
                // Find the medication and log it as taken
                if let medication = MedicationStore.shared.findMedication(with: medicationID) {
                    let reminderIndex = userInfo["reminderIndex"] as? Int
                    // Log the medication as taken (without additional check-in metadata)
                    MedicationStore.shared.logMedicationTaken(
                        medication: medication,
                        actualTime: Date(),
                        notes: nil,
                        skipped: false,
                        reminderIndex: reminderIndex
                    )
                    
                    // Provide success haptic feedback
                    HapticManager.shared.successNotification()
                    
                    // Reset badge count after action
                    NotificationManager.shared.resetApplicationBadge()
                }
            }
            
        case NotificationActionIdentifier.remindLater:
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
            
        case NotificationActionIdentifier.dismiss:
            NotificationManager.shared.resetApplicationBadge()
            completionHandler()
            return
            
        default:
            // User tapped the notification itself.
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString),
               let medication = MedicationStore.shared.findMedication(with: medicationID) {
                
                // If this is a stimulant fade notification with daily check-in enabled,
                // surface the notes & side-effects logging sheet for this medication.
                if let phase = userInfo["phase"] as? String,
                   (phase == "fade" || phase == "checkin"),
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
