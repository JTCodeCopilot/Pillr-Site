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
    
    func scheduleNotification(for medication: Medication) -> UUID {
        let content = UNMutableNotificationContent()
        content.title = "Time to take your medication"
        content.body = "It's time to take \(medication.name) (\(medication.dosage))"
        content.sound = UNNotificationSound.default
        content.userInfo = ["medicationID": medication.id.uuidString]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        // Extract hour and minute from the medication timeToTake
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: medication.timeToTake)
        let minute = calendar.component(.minute, from: medication.timeToTake)
        
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
        scheduleFollowUpNotification(for: medication, after: 30, originalID: notificationID)
        
        return notificationID
    }
    
    func scheduleFollowUpNotification(for medication: Medication, after minutes: Int, originalID: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder: Medication Due"
        content.body = "Don't forget to take your \(medication.name)"
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "medicationID": medication.id.uuidString,
            "isFollowUp": true,
            "originalNotificationID": originalID.uuidString
        ]
        content.categoryIdentifier = "MEDICATION_REMINDER"
        
        // Create a time-based trigger for the follow-up (30 minutes after scheduled time)
        let calendar = Calendar.current
        let originalTime = medication.timeToTake
        if let followUpTime = calendar.date(byAdding: .minute, value: minutes, to: originalTime) {
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
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
} 