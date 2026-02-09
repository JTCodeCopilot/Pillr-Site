//
//  NotificationManager.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import Foundation
import UserNotifications
import SwiftUI
import UIKit

fileprivate struct NotificationCategoryIdentifier {
    static let medicationReminder = "MEDICATION_REMINDER"
    static let stimulantReminder = "STIMULANT_PHASE_REMINDER"
}

fileprivate struct NotificationActionIdentifier {
    static let trackNow = "TRACK_NOW_ACTION"
    static let remindLater = "REMIND_LATER"
    static let dismiss = "DISMISS_NOTIFICATION"
}

private actor NotificationMutationQueue {
    func run<T>(_ operation: @escaping () async -> T) async -> T {
        await operation()
    }
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        setupNotificationActions()
    }
    
    var badgeCountProvider: ((Date) -> Int)?
    
    private let trackedMedicationIDsQueue = DispatchQueue(
        label: "NotificationManager.trackedMedicationIDsQueue",
        attributes: .concurrent
    )
    private let notificationMutationQueue = NotificationMutationQueue()
    private let reliabilityTelemetryQueue = DispatchQueue(label: "NotificationManager.reliabilityTelemetryQueue")
    private var trackedMedicationIDs = Set<UUID>()
    private let reminderSchedulingWindowDays = 30
    private let followUpSchedulingWindowDays = 30
    private let persistentFollowUpIntervalMinutes = 10
    private let persistentFollowUpDurationMinutes = 60
    private static let reminderDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    private static let dailyCheckInIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    private static let oneTimeReminderIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter
    }()

    func updateTrackedMedicationIDs(_ ids: Set<UUID>) {
        trackedMedicationIDsQueue.sync(flags: .barrier) {
            trackedMedicationIDs = ids
        }
    }

    func registerTrackedMedicationID(_ id: UUID) {
        trackedMedicationIDsQueue.sync(flags: .barrier) {
            trackedMedicationIDs.insert(id)
        }
    }

    func unregisterTrackedMedicationID(_ id: UUID) {
        trackedMedicationIDsQueue.sync(flags: .barrier) {
            trackedMedicationIDs.remove(id)
        }
    }

    private func isMedicationTracked(_ id: UUID) -> Bool {
        trackedMedicationIDsQueue.sync {
            trackedMedicationIDs.contains(id)
        }
    }

    private func ensureMedicationIsTracked(_ id: UUID) -> Bool {
        guard isMedicationTracked(id) else {
            cancelMedicationNotifications(for: id)
            return false
        }

        return true
    }

    private func setupNotificationActions() {
        // Define the actions
        let trackAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.trackNow,
            title: "Take Now",
            options: []
        )
        
        let remindAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.remindLater,
            title: "Remind Me in 30 Minutes",
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.dismiss,
            title: "Dismiss",
            options: .destructive
        )
        
        // Define the medication reminder category (group of actions)
        let medicationCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.medicationReminder,
            actions: [trackAction, remindAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Notification",
            categorySummaryFormat: nil,
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )

        let stimulantCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.stimulantReminder,
            actions: [dismissAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Notification",
            categorySummaryFormat: nil,
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )

        // Register all relevant notification categories
        UNUserNotificationCenter.current().setNotificationCategories([
            medicationCategory,
            stimulantCategory
        ])
    }

    private var defaultAuthorizationOptions: UNAuthorizationOptions {
        if #available(iOS 15.0, *) {
            return [.alert, .badge, .sound, .timeSensitive]
        } else {
            return [.alert, .badge, .sound]
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions? = nil, completion: ((Bool) -> Void)? = nil) {
        let authorizationOptions = options ?? defaultAuthorizationOptions
        UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions) { granted, _ in
            completion?(granted)
        }
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization(completion: completion)
            case .authorized, .provisional, .ephemeral:
                completion?(true)
            default:
                completion?(false)
            }
        }
    }

    private func prioritizeMedicationReminder(_ content: UNMutableNotificationContent) {
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
    }

    private func nextFireDate(for time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
    }

    private func applyBadge(_ content: UNMutableNotificationContent, fireDate: Date) {
        let count = badgeCountProvider?(fireDate) ?? 0
        content.badge = NSNumber(value: count)
    }

    private func followUpIdentifier(originalID: UUID, fireDate: Date, repeats: Bool) -> String {
        if repeats {
            return "\(originalID.uuidString)_followup"
        }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%@_followup_%04d%02d%02d", originalID.uuidString, year, month, day)
    }

    private func reminderIdentifier(baseID: UUID, fireDate: Date) -> String {
        let dateString = Self.reminderDayFormatter.string(from: fireDate)
        return "\(baseID.uuidString)_day_\(dateString)"
    }

    private func oneTimeReminderIdentifier(baseID: UUID, fireDate: Date) -> String {
        let dateString = Self.oneTimeReminderIDFormatter.string(from: fireDate)
        return "\(baseID.uuidString)_snooze_\(dateString)"
    }

    private func reminderIdentifierMatchesBase(_ identifier: String, baseID: String) -> Bool {
        if identifier == baseID { return true }
        return identifier.hasPrefix("\(baseID)_")
    }

    private func linkedDoseUserInfo(
        medicationID: UUID,
        baseID: UUID,
        reminderIndex: Int?,
        scheduledDoseDate: Date,
        isFollowUp: Bool
    ) -> [String: Any] {
        var userInfo: [String: Any] = [
            "medicationID": medicationID.uuidString,
            "originalNotificationID": baseID.uuidString,
            "reminderBaseID": baseID.uuidString,
            "scheduledDoseAt": scheduledDoseDate.timeIntervalSince1970,
            "scheduleDayKey": Self.reminderDayFormatter.string(from: scheduledDoseDate)
        ]
        if let reminderIndex {
            userInfo["reminderIndex"] = reminderIndex
        }
        if isFollowUp {
            userInfo["isFollowUp"] = true
        }
        return userInfo
    }

    private func medicationDescriptor(for medication: Medication) -> String {
        if medication.medicationType == .other {
            return medication.name
        }
        return "\(medication.name) (\(medication.medicationType.displayName))"
    }

    private enum ReliabilityEvent: String {
        case reminderScheduled
        case reminderRescheduled
        case reminderRepairApplied
        case notificationMutationError
    }

    private func recordReliabilityEvent(_ event: ReliabilityEvent, amount: Int = 1) {
        reliabilityTelemetryQueue.async {
            let key = "notification_reliability_\(event.rawValue)"
            let current = UserDefaults.standard.integer(forKey: key)
            UserDefaults.standard.set(current + amount, forKey: key)
        }
    }

    private func enqueueNotificationMutation(_ operation: @escaping () async -> Void) {
        Task {
            _ = await notificationMutationQueue.run(operation)
        }
    }

    private func pendingRequestsSnapshot() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func deliveredNotificationsSnapshot() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    private func addNotificationRequest(
        _ request: UNNotificationRequest,
        context: String
    ) async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { [weak self] error in
                if let error {
                    print("Error scheduling \(context): \(error.localizedDescription)")
                    self?.recordReliabilityEvent(.notificationMutationError)
                }
                continuation.resume()
            }
        }
    }

    private func localTimeOnDay(
        calendar: Calendar,
        hour: Int,
        minute: Int,
        day: Date
    ) -> Date? {
        if let exact = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) {
            return exact
        }

        guard let next = calendar.nextDate(
            after: day,
            matching: DateComponents(hour: hour, minute: minute, second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ), calendar.isDate(next, inSameDayAs: day) else {
            return nil
        }

        return next
    }

    
    // Legacy support for single notification
    func scheduleNotification(for medication: Medication) -> UUID? {
        guard medication.frequency != "As needed", ensureMedicationIsTracked(medication.id) else {
            return nil
        }

        let notificationID = UUID()
        scheduleReminderWindow(
            medication: medication,
            time: medication.timeToTake,
            baseID: notificationID,
            reminderIndex: nil
        )
        for offset in followUpOffsets(for: medication) {
            scheduleFollowUpNotificationsWindow(
                for: medication,
                time: medication.timeToTake,
                index: 0,
                after: offset,
                originalID: notificationID
            )
        }
        return notificationID
    }
    
    // New method for scheduling multiple notifications
    func scheduleMultipleNotifications(for medication: Medication) -> [UUID] {
        guard medication.frequency != "As needed", ensureMedicationIsTracked(medication.id) else {
            return []
        }

        var notificationIDs: [UUID] = []
        
        // Use reminderTimes if available, otherwise fall back to legacy timeToTake
        let times = medication.reminderTimes.isEmpty ? [medication.timeToTake] : medication.reminderTimes
        
        for (index, reminderTime) in times.enumerated() {
            let notificationID = scheduleNotificationForTime(
                medication: medication,
                time: reminderTime,
                index: index
            )
            notificationIDs.append(notificationID)
        }
        
        return notificationIDs
    }
    
    private func scheduleNotificationForTime(medication: Medication, time: Date, index: Int) -> UUID {
        let notificationID = UUID()
        scheduleReminderWindow(
            medication: medication,
            time: time,
            baseID: notificationID,
            reminderIndex: index
        )

        for offset in followUpOffsets(for: medication) {
            scheduleFollowUpNotificationsWindow(
                for: medication,
                time: time,
                index: index,
                after: offset,
                originalID: notificationID
            )
        }
        
        
        return notificationID
    }

    private func followUpOffsets(for medication: Medication) -> [Int] {
        guard UserSettings.shared.isPremiumUser else {
            return []
        }

        if medication.isPersistentReminder {
            return Array(
                stride(
                    from: persistentFollowUpIntervalMinutes,
                    through: persistentFollowUpDurationMinutes,
                    by: persistentFollowUpIntervalMinutes
                )
            )
        }

        if medication.isOneTimeWithFollowUp {
            return [30]
        }

        return []
    }

    private func scheduleReminderWindow(
        medication: Medication,
        time: Date,
        baseID: UUID,
        reminderIndex: Int?
    ) {
        let calendar = Calendar.current
        let formattedTime = formatTimeOnly(time)

        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let existingIdentifiers = Set((await self.pendingRequestsSnapshot()).map { $0.identifier })
            var knownIdentifiers = existingIdentifiers
            let maxPendingReminders = 60
            var remainingSlots = max(0, maxPendingReminders - knownIdentifiers.count)
            guard remainingSlots > 0 else { return }
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)

            for dayOffset in 0..<self.reminderSchedulingWindowDays {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                      let fireDate = self.localTimeOnDay(
                        calendar: calendar,
                        hour: hour,
                        minute: minute,
                        day: day
                      ),
                      fireDate > now else {
                    continue
                }

                let identifier = self.reminderIdentifier(baseID: baseID, fireDate: fireDate)
                guard !knownIdentifiers.contains(identifier) else { continue }
                guard remainingSlots > 0 else { break }

                let content = UNMutableNotificationContent()
                content.title = "Medication Reminder"
                content.body = "Take your \(formattedTime) medications."
                content.sound = UNNotificationSound.default
                content.userInfo = self.linkedDoseUserInfo(
                    medicationID: medication.id,
                    baseID: baseID,
                    reminderIndex: reminderIndex,
                    scheduledDoseDate: fireDate,
                    isFollowUp: false
                )
                content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
                content.threadIdentifier = "medication-reminders"
                self.applyBadge(content, fireDate: fireDate)
                self.prioritizeMedicationReminder(content)

                let triggerComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                await self.addNotificationRequest(request, context: "notification")
                self.recordReliabilityEvent(.reminderScheduled)
                knownIdentifiers.insert(identifier)
                remainingSlots -= 1
            }
        }
    }

    private func scheduleSingleReminderOccurrence(
        medication: Medication,
        fireDate: Date,
        baseID: UUID,
        reminderIndex: Int?
    ) {
        let content = UNMutableNotificationContent()
        let formattedTime = formatTimeOnly(fireDate)
        content.title = "Medication Reminder"
        content.body = "Take your \(formattedTime) medications."
        content.sound = UNNotificationSound.default
        content.userInfo = linkedDoseUserInfo(
            medicationID: medication.id,
            baseID: baseID,
            reminderIndex: reminderIndex,
            scheduledDoseDate: fireDate,
            isFollowUp: false
        )
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        applyBadge(content, fireDate: fireDate)
        prioritizeMedicationReminder(content)

        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier(baseID: baseID, fireDate: fireDate),
            content: content,
            trigger: trigger
        )
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            await self.addNotificationRequest(request, context: "notification")
            self.recordReliabilityEvent(.reminderRescheduled)
        }
    }

    func rescheduleReminderOccurrenceIfPending(
        medication: Medication,
        time: Date,
        baseID: UUID,
        reminderIndex: Int?,
        referenceDate: Date = Date()
    ) {
        guard medication.frequency != "As needed" else { return }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let fireDate = localTimeOnDay(
            calendar: calendar,
            hour: components.hour ?? 8,
            minute: components.minute ?? 0,
            day: dayStart
        ), fireDate > referenceDate else {
            return
        }

        cancelReminderOccurrence(for: baseID, on: fireDate)
        scheduleSingleReminderOccurrence(
            medication: medication,
            fireDate: fireDate,
            baseID: baseID,
            reminderIndex: reminderIndex
        )
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    func scheduleFollowUpNotification(for medication: Medication, after minutes: Int, originalID: UUID) {
        guard ensureMedicationIsTracked(medication.id) else {
            return
        }

        scheduleFollowUpNotificationsWindow(
            for: medication,
            time: medication.timeToTake,
            index: 0,
            after: minutes,
            originalID: originalID
        )
    }

    func scheduleFollowUpNotification(
        for medication: Medication,
        time: Date,
        index: Int,
        after minutes: Int,
        originalID: UUID,
        repeats: Bool = true
    ) {
        guard ensureMedicationIsTracked(medication.id) else {
            return
        }
        let content = UNMutableNotificationContent()

        content.title = "Medications Follow Up"
        let formattedTime = formatTimeOnly(time)
        content.body = "Time to log your \(formattedTime) medications."

        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        prioritizeMedicationReminder(content)
        
        // Create a time-based trigger for the follow-up (30 minutes after scheduled time)
        let calendar = Calendar.current
        if let followUpTime = calendar.date(byAdding: .minute, value: minutes, to: time) {
            content.userInfo = linkedDoseUserInfo(
                medicationID: medication.id,
                baseID: originalID,
                reminderIndex: index,
                scheduledDoseDate: time,
                isFollowUp: true
            )
            let badgeFireDate = repeats ? nextFireDate(for: followUpTime) : followUpTime
            applyBadge(content, fireDate: badgeFireDate)
            let followUpHour = calendar.component(.hour, from: followUpTime)
            let followUpMinute = calendar.component(.minute, from: followUpTime)
            
            var dateComponents = DateComponents()
            dateComponents.hour = followUpHour
            dateComponents.minute = followUpMinute
            if !repeats {
                let fullComponents = calendar.dateComponents([.year, .month, .day], from: followUpTime)
                dateComponents.year = fullComponents.year
                dateComponents.month = fullComponents.month
                dateComponents.day = fullComponents.day
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
            
            // Create a unique ID for the follow-up by adding a suffix
            let followUpID = followUpIdentifier(originalID: originalID, fireDate: followUpTime, repeats: repeats)
            let request = UNNotificationRequest(identifier: followUpID, content: content, trigger: trigger)
            
            enqueueNotificationMutation { [weak self] in
                guard let self else { return }
                await self.addNotificationRequest(request, context: "follow-up notification")
            }
        }
    }

    private func scheduleFollowUpNotificationsWindow(
        for medication: Medication,
        time: Date,
        index: Int,
        after minutes: Int,
        originalID: UUID
    ) {
        guard ensureMedicationIsTracked(medication.id) else {
            return
        }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = timeComponents.hour,
              let minute = timeComponents.minute else {
            return
        }

        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let existingIdentifiers = Set((await self.pendingRequestsSnapshot()).map { $0.identifier })
            var knownIdentifiers = existingIdentifiers
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)

            for dayOffset in 0..<self.followUpSchedulingWindowDays {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                      let baseDate = self.localTimeOnDay(
                        calendar: calendar,
                        hour: hour,
                        minute: minute,
                        day: day
                      ),
                      let followUpDate = calendar.date(byAdding: .minute, value: minutes, to: baseDate),
                      followUpDate > now else {
                    continue
                }

                let identifier = self.followUpIdentifier(
                    originalID: originalID,
                    fireDate: followUpDate,
                    repeats: false
                )
                guard !knownIdentifiers.contains(identifier) else { continue }

                self.scheduleFollowUpNotification(
                    for: medication,
                    time: baseDate,
                    index: index,
                    after: minutes,
                    originalID: originalID,
                    repeats: false
                )
                knownIdentifiers.insert(identifier)
            }
        }
    }
    
    func scheduleOneTimeReminder(
        for medication: Medication,
        afterMinutes: Int,
        sourceNotificationBaseID: UUID? = nil,
        reminderIndex: Int? = nil,
        scheduledDoseDate: Date? = nil
    ) {
        guard ensureMedicationIsTracked(medication.id) else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Reminder: Take Your Medication"
        content.body = "It's time to take your medication."
        content.sound = UNNotificationSound.default
        let fireDate = Date().addingTimeInterval(TimeInterval(afterMinutes * 60))
        let baseID = sourceNotificationBaseID ?? UUID()
        let scheduledDate = scheduledDoseDate ?? Date()
        content.userInfo = linkedDoseUserInfo(
            medicationID: medication.id,
            baseID: baseID,
            reminderIndex: reminderIndex,
            scheduledDoseDate: scheduledDate,
            isFollowUp: true
        )
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        content.threadIdentifier = "medication-reminders"
        applyBadge(content, fireDate: fireDate)
        prioritizeMedicationReminder(content)

        // Create a time-based trigger for one-time reminder
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(afterMinutes * 60), repeats: false)
        
        // Keep snoozes deterministic to avoid multiple orphaned reminders for one dose.
        let reminderID = oneTimeReminderIdentifier(baseID: baseID, fireDate: fireDate)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        
        // Add the reminder notification
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
            await self.addNotificationRequest(request, context: "one-time reminder")
        }
    }
    
    func cancelNotification(with id: UUID) {
        let baseID = id.uuidString
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let pending = await self.pendingRequestsSnapshot()
            let pendingIDs = pending.compactMap { request -> String? in
                self.reminderIdentifierMatchesBase(request.identifier, baseID: baseID) ? request.identifier : nil
            }
            if !pendingIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIDs)
            }

            let delivered = await self.deliveredNotificationsSnapshot()
            let deliveredIDs = delivered.compactMap { notification -> String? in
                self.reminderIdentifierMatchesBase(notification.request.identifier, baseID: baseID)
                    ? notification.request.identifier
                    : nil
            }
            if !deliveredIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIDs)
            }
        }
    }

    func clearDeliveredNotifications(for id: UUID) {
        let baseID = id.uuidString
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let delivered = await self.deliveredNotificationsSnapshot()
            let identifiers = delivered.compactMap { notification -> String? in
                self.reminderIdentifierMatchesBase(notification.request.identifier, baseID: baseID)
                    ? notification.request.identifier
                    : nil
            }
            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }

    func cancelFollowUpNotification(for baseID: UUID, on date: Date = Date()) {
        let followUpID = followUpIdentifier(originalID: baseID, fireDate: date, repeats: false)
        enqueueNotificationMutation {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [followUpID])
        }
    }

    func cancelFollowUpNotifications(for baseID: UUID) {
        let prefix = "\(baseID.uuidString)_followup"
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let pending = await self.pendingRequestsSnapshot()
            let pendingIDs = pending.compactMap { request -> String? in
                request.identifier.hasPrefix(prefix) ? request.identifier : nil
            }
            if !pendingIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIDs)
            }

            let delivered = await self.deliveredNotificationsSnapshot()
            let deliveredIDs = delivered.compactMap { notification -> String? in
                notification.request.identifier.hasPrefix(prefix) ? notification.request.identifier : nil
            }
            if !deliveredIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIDs)
            }
        }
    }
    
    func cancelMultipleNotifications(ids: [UUID]) {
        for id in ids {
            cancelNotification(with: id)
        }
    }

    /// Removes any medication reminder notifications for a specific medication that do not match
    /// the provided identifiers. This lets us clear ad-hoc reminders (e.g., snoozes) without
    /// touching the primary scheduled reminders that belong to the medication.
    func removeUntrackedMedicationReminders(
        for medicationID: UUID,
        preservingIdentifiers identifiersToKeep: Set<String>
    ) {
        let medicationIDString = medicationID.uuidString
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let pending = await self.pendingRequestsSnapshot()
            let pendingIDs = pending.compactMap { request -> String? in
                guard let pendingMedicationID = request.content.userInfo["medicationID"] as? String,
                      pendingMedicationID == medicationIDString,
                      request.content.categoryIdentifier == NotificationCategoryIdentifier.medicationReminder else {
                    return nil
                }

                let shouldKeep = identifiersToKeep.contains { baseID in
                    request.identifier == baseID || request.identifier.hasPrefix("\(baseID)_")
                }
                return shouldKeep ? nil : request.identifier
            }
            if !pendingIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIDs)
            }

            let delivered = await self.deliveredNotificationsSnapshot()
            let deliveredIDs = delivered.compactMap { notification -> String? in
                guard let deliveredMedicationID = notification.request.content.userInfo["medicationID"] as? String,
                      deliveredMedicationID == medicationIDString,
                      notification.request.content.categoryIdentifier == NotificationCategoryIdentifier.medicationReminder else {
                    return nil
                }

                let shouldKeep = identifiersToKeep.contains { baseID in
                    notification.request.identifier == baseID || notification.request.identifier.hasPrefix("\(baseID)_")
                }
                return shouldKeep ? nil : notification.request.identifier
            }
            if !deliveredIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIDs)
            }
        }
    }

    /// Cancels any pending or delivered notifications that reference the provided medication ID.
    /// This is used as a safety net for deleted medications where we no longer want reminders firing.
    func cancelMedicationNotifications(for medicationID: UUID) {
        let medicationIDString = medicationID.uuidString
        let refillPrefix = "refill-\(medicationIDString)"
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let pending = await self.pendingRequestsSnapshot()
            let pendingIDs = pending.compactMap { request -> String? in
                if let pendingMedicationID = request.content.userInfo["medicationID"] as? String,
                   pendingMedicationID == medicationIDString {
                    return request.identifier
                }

                if request.identifier.hasPrefix(refillPrefix) {
                    return request.identifier
                }

                return nil
            }
            if !pendingIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIDs)
            }

            let delivered = await self.deliveredNotificationsSnapshot()
            let deliveredIDs = delivered.compactMap { notification -> String? in
                if let deliveredMedicationID = notification.request.content.userInfo["medicationID"] as? String,
                   deliveredMedicationID == medicationIDString {
                    return notification.request.identifier
                }

                if notification.request.identifier.hasPrefix(refillPrefix) {
                    return notification.request.identifier
                }

                return nil
            }
            if !deliveredIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIDs)
            }
        }
    }

    func cancelReminderOccurrence(for baseID: UUID, on date: Date) {
        let identifier = reminderIdentifier(baseID: baseID, fireDate: date)
        enqueueNotificationMutation {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }

    func fetchDeliveredMedicationReminders(completion: @escaping ([UNNotification]) -> Void) {
        Task { [weak self] in
            guard let self else {
                completion([])
                return
            }
            let reminders = await notificationMutationQueue.run {
                let notifications = await self.deliveredNotificationsSnapshot()
                return notifications.filter { notification in
                    notification.request.content.categoryIdentifier == NotificationCategoryIdentifier.medicationReminder
                }
            }
            completion(reminders)
        }
    }

    func fetchPendingMedicationReminders(completion: @escaping ([UNNotificationRequest]) -> Void) {
        Task { [weak self] in
            guard let self else {
                completion([])
                return
            }
            let reminders = await notificationMutationQueue.run {
                let requests = await self.pendingRequestsSnapshot()
                return requests.filter { request in
                    request.content.categoryIdentifier == NotificationCategoryIdentifier.medicationReminder
                }
            }
            completion(reminders)
        }
    }

    func clearDeliveredMedicationReminders() {
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let notifications = await self.deliveredNotificationsSnapshot()
            let identifiers = notifications.compactMap { notification -> String? in
                notification.request.content.categoryIdentifier == NotificationCategoryIdentifier.medicationReminder
                    ? notification.request.identifier
                    : nil
            }
            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }

    func cancelNotifications(forMedicationID medicationID: UUID) {
        cancelMedicationNotifications(for: medicationID)
    }
    
    func cancelAllNotifications() {
        enqueueNotificationMutation {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
        resetApplicationBadge()
    }

    /// Removes any pending/delivered medication reminder notifications that don't belong to the provided set of active medications.
    /// Useful on app launch to clear reminders for medications that were deleted while the app was not running.
    func purgeNotifications(excluding validMedicationIDs: Set<UUID>) {
        let validIDStrings = Set(validMedicationIDs.map { $0.uuidString })
        let refillPrefix = "refill-"
        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let pending = await self.pendingRequestsSnapshot()
            let pendingIDs = pending.compactMap { request -> String? in
                if let medicationID = request.content.userInfo["medicationID"] as? String {
                    return validIDStrings.contains(medicationID) ? nil : request.identifier
                }

                if request.identifier.hasPrefix(refillPrefix) {
                    let suffix = String(request.identifier.dropFirst(refillPrefix.count))
                    return validIDStrings.contains(suffix) ? nil : request.identifier
                }

                return nil
            }
            if !pendingIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIDs)
            }

            let delivered = await self.deliveredNotificationsSnapshot()
            let deliveredIDs = delivered.compactMap { notification -> String? in
                if let medicationID = notification.request.content.userInfo["medicationID"] as? String {
                    return validIDStrings.contains(medicationID) ? nil : notification.request.identifier
                }

                if notification.request.identifier.hasPrefix(refillPrefix) {
                    let suffix = String(notification.request.identifier.dropFirst(refillPrefix.count))
                    return validIDStrings.contains(suffix) ? nil : notification.request.identifier
                }

                return nil
            }

            if !deliveredIDs.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredIDs)
            }
        }
    }
    
    // Function to reset the application badge to zero
    func resetApplicationBadge() {
        setApplicationBadge(count: 0)
    }

    func setApplicationBadge(count: Int) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("Error setting badge count: \(error.localizedDescription)")
                }
            }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
    
    // MARK: - Stimulant phase notifications

    private func resolvedStimulantTiming(for medication: Medication) -> (onset: Int, duration: Int)? {
        guard let onset = medication.onsetMinutes,
              let duration = medication.durationMinutes else {
            return nil
        }

        return (onset, duration)
    }

    func scheduleStimulantPhaseNotifications(for medication: Medication, doseTime: Date, logID: UUID) {
        let shouldScheduleFadeCheckIn = medication.enableDailyCheckIn && medication.dailyCheckInTime == nil
        guard ensureMedicationIsTracked(medication.id),
              medication.enableStimulantPhaseNotifications,
              medication.medicationType == .stimulant,
              shouldScheduleFadeCheckIn,
              let timing = resolvedStimulantTiming(for: medication) else {
            return
        }

        let calendar = Calendar.current
        let descriptor = medicationDescriptor(for: medication)
        let duration = timing.duration
        if let fadeWarningDate = calendar.date(byAdding: .minute, value: duration, to: doseTime) {
            let fadeTitle = "Check in as your medication fades"
            let fadeBody = "How was your focus and side effects today? Tap to log when \(descriptor) starts wearing off."

            scheduleNotification(
                for: medication,
                title: fadeTitle,
                body: fadeBody,
                userInfo: [
                    "medicationID": medication.id.uuidString,
                    "phase": "fade",
                    "isDailyCheckIn": true,
                    "logID": logID.uuidString
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
        guard ensureMedicationIsTracked(medication.id), interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.userInfo = userInfo
        content.categoryIdentifier = category
        content.threadIdentifier = "medication-reminders"
        applyBadge(content, fireDate: fireDate)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }

        let request = UNNotificationRequest(
            identifier: "\(medication.id.uuidString)_\(identifierSuffix)_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )

        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            await self.addNotificationRequest(request, context: "\(identifierSuffix) notification")
        }
    }

    func scheduleDailyCheckInReminder(for medication: Medication, referenceDate: Date) {
        guard ensureMedicationIsTracked(medication.id) else {
            return
        }

        guard medication.enableDailyCheckIn else {
            return
        }

        let calendar = Calendar.current
        let checkInTime = medication.dailyCheckInTime
            ?? calendar.date(bySettingHour: 19, minute: 0, second: 0, of: referenceDate)
            ?? referenceDate
        let checkInComponents = calendar.dateComponents([.hour, .minute], from: checkInTime)

        guard let hour = checkInComponents.hour,
              let minute = checkInComponents.minute else {
            return
        }

        let noteBody = "Take a moment to reflect on how you felt today taking \(medication.name)."

        let content = UNMutableNotificationContent()
        content.title = "Reflection"
        content.body = noteBody
        content.sound = UNNotificationSound.default
        content.userInfo = [
            "medicationID": medication.id.uuidString,
            "phase": "checkin",
            "isDailyCheckIn": true
        ]
        content.categoryIdentifier = NotificationCategoryIdentifier.stimulantReminder
        content.threadIdentifier = "medication-reminders"
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }

        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let existingIdentifiers = Set((await self.pendingRequestsSnapshot()).map { $0.identifier })
            let now = Date()
            let startOfDay = calendar.startOfDay(for: referenceDate)
            guard let fireDate = self.localTimeOnDay(
                calendar: calendar,
                hour: hour,
                minute: minute,
                day: startOfDay
            ), fireDate > now else {
                return
            }

            let identifier = self.dailyCheckInIdentifier(for: medication.id, date: fireDate)
            guard !existingIdentifiers.contains(identifier) else { return }

            self.applyBadge(content, fireDate: fireDate)
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            await self.addNotificationRequest(request, context: "Reflection notification")
        }
    }

    func cancelDailyCheckInNotification(for medicationID: UUID, on date: Date) {
        let identifier = dailyCheckInIdentifier(for: medicationID, date: date)
        enqueueNotificationMutation {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }

    private func dailyCheckInIdentifier(for medicationID: UUID, date: Date) -> String {
        let dateString = Self.dailyCheckInIDFormatter.string(from: date)
        return "\(medicationID.uuidString)_checkin_\(dateString)"
    }

    func cancelPendingDailyCheckInNotifications(for medicationID: UUID) {
        let medicationIDString = medicationID.uuidString

        enqueueNotificationMutation { [weak self] in
            guard let self else { return }
            let requests = await self.pendingRequestsSnapshot()
            let identifiers = requests.compactMap { request -> String? in
                guard let pendingMedicationID = request.content.userInfo["medicationID"] as? String,
                      pendingMedicationID == medicationIDString,
                      let phase = request.content.userInfo["phase"] as? String,
                      phase == "checkin" else {
                    return nil
                }

                return request.identifier
            }

            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
    }

    func surfaceDeliveredStimulantCheckInsIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            let notifications = await notificationMutationQueue.run {
                await self.deliveredNotificationsSnapshot()
            }
            await MainActor.run {
                let candidates = notifications
                    .filter { $0.request.content.categoryIdentifier == NotificationCategoryIdentifier.stimulantReminder }
                    .sorted { $0.date < $1.date }

                guard !candidates.isEmpty else { return }

                var pending: [PendingCheckIn] = []
                var identifiersToRemove: [String] = []

                for notification in candidates {
                    let result = self.pendingCheckIn(from: notification)
                    if let checkIn = result.checkIn {
                        pending.append(checkIn)
                    }
                    if result.shouldRemove {
                        identifiersToRemove.append(notification.request.identifier)
                    }
                }

                if !pending.isEmpty {
                    MedicationStore.shared.enqueuePendingCheckIns(pending)
                }

                if !identifiersToRemove.isEmpty {
                    self.enqueueNotificationMutation {
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
                    }
                }
            }
        }
    }

    private struct DeliveredCheckInResult {
        let checkIn: PendingCheckIn?
        let shouldRemove: Bool
    }

    @MainActor
    private func pendingCheckIn(from notification: UNNotification) -> DeliveredCheckInResult {
        let userInfo = notification.request.content.userInfo
        guard let medicationIDString = userInfo["medicationID"] as? String,
              let medicationID = UUID(uuidString: medicationIDString) else {
            return DeliveredCheckInResult(checkIn: nil, shouldRemove: true)
        }

        guard let medication = MedicationStore.shared.findMedication(with: medicationID) else {
            cancelMedicationNotifications(for: medicationID)
            return DeliveredCheckInResult(checkIn: nil, shouldRemove: true)
        }

        guard let phase = userInfo["phase"] as? String else {
            return DeliveredCheckInResult(checkIn: nil, shouldRemove: true)
        }

        if phase == "checkin" {
            guard medication.enableDailyCheckIn else {
                return DeliveredCheckInResult(checkIn: nil, shouldRemove: true)
            }
            let context = DailyCheckInContext(medication: medication, entrySource: .notification)
            return DeliveredCheckInResult(checkIn: .daily(context), shouldRemove: true)
        }

        if phase == "fade",
           let isDailyCheckIn = userInfo["isDailyCheckIn"] as? Bool,
           isDailyCheckIn,
           let logIDString = userInfo["logID"] as? String,
           let logID = UUID(uuidString: logIDString),
           medication.enableDailyCheckIn {
            let context = DailyCheckInContext(
                medication: medication,
                logID: logID,
                entrySource: .notification
            )
            return DeliveredCheckInResult(checkIn: .daily(context), shouldRemove: true)
        }

        return DeliveredCheckInResult(checkIn: nil, shouldRemove: true)
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
    static let shared = NotificationDelegate(
        notificationManager: NotificationManager.shared,
        medicationStore: MedicationStore.shared
    )
    
    private let notificationManager: NotificationManagerProtocol
    private let medicationStore: MedicationStore
    @MainActor private var processedActionTimestamps: [String: Date] = [:]
    private let processedActionTTL: TimeInterval = 120
    
    init(
        notificationManager: NotificationManagerProtocol,
        medicationStore: MedicationStore
    ) {
        self.notificationManager = notificationManager
        self.medicationStore = medicationStore
        super.init()
    }
    
    // Called when a notification is delivered to a foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            if let medicationIDString = notification.request.content.userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString),
               medicationStore.findMedication(with: medicationID) == nil {
                notificationManager.cancelMedicationNotifications(for: medicationID)
                completionHandler([])
                return
            }

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

            if notification.request.content.categoryIdentifier == NotificationCategoryIdentifier.medicationReminder {
                medicationStore.refreshOverdueMedicationIDs(referenceDate: notification.date)
            }

            // Allow the notification to present with sound, banner, and list
            completionHandler([.sound, .banner, .list])
        }
    }
    
    // Called when a user responds to a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            let userInfo = response.notification.request.content.userInfo
            handleNotification(
                actionIdentifier: response.actionIdentifier,
                userInfo: userInfo,
                notificationIdentifier: response.notification.request.identifier,
                categoryIdentifier: response.notification.request.content.categoryIdentifier,
                notificationDate: response.notification.date,
                completionHandler: completionHandler
            )
        }
    }

    @MainActor
    private func handleNotification(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any],
        notificationIdentifier: String,
        categoryIdentifier: String,
        notificationDate: Date,
        completionHandler: @escaping () -> Void
    ) {
        guard shouldProcessAction(
            actionIdentifier: actionIdentifier,
            userInfo: userInfo,
            notificationIdentifier: notificationIdentifier
        ) else {
            completionHandler()
            return
        }

        if let medicationIDString = userInfo["medicationID"] as? String,
           let medicationID = UUID(uuidString: medicationIDString),
           medicationStore.findMedication(with: medicationID) == nil {
            recordDelegateReliabilityEvent("missing_medication_action")
            notificationManager.cancelMedicationNotifications(for: medicationID)
            medicationStore.checkAndResetBadge()
            completionHandler()
            return
        }

        switch actionIdentifier {
        case NotificationActionIdentifier.trackNow:
                if let medicationIDString = userInfo["medicationID"] as? String,
                   let medicationID = UUID(uuidString: medicationIDString),
                   let medication = medicationStore.findMedication(with: medicationID) {
                let reminderIndex = reminderIndex(from: userInfo)
                medicationStore.logMedicationTaken(
                    medication: medication,
                    actualTime: Date(),
                    notes: nil,
                    skipped: false,
                    reminderIndex: reminderIndex
                )
            }
            cancelNotifications(
                userInfo: userInfo,
                notificationIdentifier: notificationIdentifier
            )
            if let baseUUID = resolveBaseNotificationUUID(
                userInfo: userInfo,
                notificationIdentifier: notificationIdentifier
            ) {
                notificationManager.cancelFollowUpNotifications(for: baseUUID)
            }
            medicationStore.checkAndResetBadge()

        case NotificationActionIdentifier.remindLater:
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString) {
                if let medication = medicationStore.findMedication(with: medicationID) {
                    let reminderIndex = reminderIndex(from: userInfo)
                    let scheduledDoseDate = scheduledDoseDate(from: userInfo) ?? notificationDate
                    let baseUUID = resolveBaseNotificationUUID(
                        userInfo: userInfo,
                        notificationIdentifier: notificationIdentifier
                    )
                    if let baseUUID {
                        let followUpDate = Calendar.current.date(
                            byAdding: .minute,
                            value: 30,
                            to: notificationDate
                        ) ?? Date()
                        notificationManager.cancelFollowUpNotification(for: baseUUID, on: followUpDate)
                    }
                    notificationManager.scheduleOneTimeReminder(
                        for: medication,
                        afterMinutes: 30,
                        sourceNotificationBaseID: baseUUID,
                        reminderIndex: reminderIndex,
                        scheduledDoseDate: scheduledDoseDate
                    )
                    HapticManager.shared.lightImpact()
                }
            }

        case NotificationActionIdentifier.dismiss:
            medicationStore.checkAndResetBadge()
            completionHandler()
            return

        default:
            if let medicationIDString = userInfo["medicationID"] as? String,
               let medicationID = UUID(uuidString: medicationIDString),
               let medication = medicationStore.findMedication(with: medicationID) {
                    if categoryIdentifier == NotificationCategoryIdentifier.medicationReminder {
                        medicationStore.highlightedMedicationID = medication.id
                        medicationStore.notificationHighlightMedicationID = medication.id
                        medicationStore.requestedMainTab = .meds
                    }

                if let phase = userInfo["phase"] as? String {
                    if phase == "checkin", medication.enableDailyCheckIn {
                        medicationStore.dailyCheckInContext = DailyCheckInContext(
                            medication: medication,
                            entrySource: .notification
                        )
                    } else if phase == "fade",
                              let isDailyCheckIn = userInfo["isDailyCheckIn"] as? Bool,
                              isDailyCheckIn,
                              let logIDString = userInfo["logID"] as? String,
                              let logID = UUID(uuidString: logIDString),
                              medication.enableDailyCheckIn {
                        medicationStore.dailyCheckInContext = DailyCheckInContext(
                            medication: medication,
                            logID: logID,
                            entrySource: .notification
                        )
                    }
                }

                medicationStore.checkAndResetBadge()
            } else {
                medicationStore.checkAndResetBadge()
            }
        }

        completionHandler()
    }

    private func cancelNotifications(
        userInfo: [AnyHashable: Any],
        notificationIdentifier: String
    ) {
        if let baseUUID = resolveBaseNotificationUUID(
            userInfo: userInfo,
            notificationIdentifier: notificationIdentifier
        ) {
            notificationManager.cancelNotification(with: baseUUID)
            return
        }

        guard let baseUUID = baseNotificationUUID(from: notificationIdentifier) else { return }
        notificationManager.cancelNotification(with: baseUUID)
    }

    private func resolveBaseNotificationUUID(
        userInfo: [AnyHashable: Any],
        notificationIdentifier: String
    ) -> UUID? {
        if let baseIDString = userInfo["reminderBaseID"] as? String,
           let baseUUID = UUID(uuidString: baseIDString) {
            return baseUUID
        }
        if let originalIDString = userInfo["originalNotificationID"] as? String,
           let originalUUID = UUID(uuidString: originalIDString) {
            return originalUUID
        }
        return baseNotificationUUID(from: notificationIdentifier)
    }

    private func baseNotificationUUID(from identifier: String) -> UUID? {
        if let separatorIndex = identifier.firstIndex(of: "_") {
            let baseString = String(identifier[..<separatorIndex])
            return UUID(uuidString: baseString)
        }
        return UUID(uuidString: identifier)
    }

    private func reminderIndex(from userInfo: [AnyHashable: Any]) -> Int? {
        if let value = userInfo["reminderIndex"] as? Int {
            return value
        }
        if let value = userInfo["reminderIndex"] as? NSNumber {
            return value.intValue
        }
        if let value = userInfo["reminderIndex"] as? String {
            return Int(value)
        }
        return nil
    }

    private func scheduledDoseDate(from userInfo: [AnyHashable: Any]) -> Date? {
        if let unix = userInfo["scheduledDoseAt"] as? TimeInterval {
            return Date(timeIntervalSince1970: unix)
        }
        if let unix = userInfo["scheduledDoseAt"] as? NSNumber {
            return Date(timeIntervalSince1970: unix.doubleValue)
        }
        return nil
    }

    @MainActor
    private func shouldProcessAction(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any],
        notificationIdentifier: String
    ) -> Bool {
        guard actionIdentifier == NotificationActionIdentifier.trackNow
            || actionIdentifier == NotificationActionIdentifier.remindLater else {
            return true
        }

        let now = Date()
        processedActionTimestamps = processedActionTimestamps.filter {
            now.timeIntervalSince($0.value) < processedActionTTL
        }

        let medicationID = userInfo["medicationID"] as? String ?? "unknown-medication"
        let reminderIndexToken = reminderIndex(from: userInfo).map(String.init) ?? "none"
        let scheduleToken = (userInfo["scheduleDayKey"] as? String)
            ?? scheduledDoseDate(from: userInfo).map {
                dayKey(from: $0)
            }
            ?? "unknown-day"
        let key = [
            actionIdentifier,
            notificationIdentifier,
            medicationID,
            reminderIndexToken,
            scheduleToken
        ].joined(separator: "|")

        if processedActionTimestamps[key] != nil {
            recordDelegateReliabilityEvent("duplicate_action_suppressed")
            return false
        }

        processedActionTimestamps[key] = now
        return true
    }

    private func recordDelegateReliabilityEvent(_ event: String, amount: Int = 1) {
        let key = "notification_reliability_delegate_\(event)"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + amount, forKey: key)
    }

    private func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

#if DEBUG
    @MainActor
    func _test_handleNotification(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any],
        notificationIdentifier: String,
        categoryIdentifier: String,
        notificationDate: Date
    ) {
        handleNotification(
            actionIdentifier: actionIdentifier,
            userInfo: userInfo,
            notificationIdentifier: notificationIdentifier,
            categoryIdentifier: categoryIdentifier,
            notificationDate: notificationDate,
            completionHandler: {}
        )
    }
#endif
}
