import Foundation
import UserNotifications

protocol NotificationManagerProtocol: AnyObject {
    var badgeCountProvider: ((Date) -> Int)? { get set }

    func updateTrackedMedicationIDs(_ ids: Set<UUID>)
    func registerTrackedMedicationID(_ id: UUID)
    func unregisterTrackedMedicationID(_ id: UUID)

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)?)

    func scheduleNotification(for medication: Medication) -> UUID?
    func scheduleMultipleNotifications(for medication: Medication) -> [UUID]
    func scheduleOneTimeReminder(
        for medication: Medication,
        afterMinutes: Int,
        sourceNotificationBaseID: UUID?,
        reminderIndex: Int?,
        scheduledDoseDate: Date?
    )
    func scheduleStimulantPhaseNotifications(for medication: Medication, doseTime: Date, logID: UUID)
    func scheduleDailyCheckInReminder(for medication: Medication, referenceDate: Date)

    func cancelNotification(with id: UUID)
    func cancelMultipleNotifications(ids: [UUID])
    func cancelMedicationNotifications(for medicationID: UUID)
    func cancelReminderOccurrence(for baseID: UUID, on date: Date)
    func cancelFollowUpNotification(for baseID: UUID, on date: Date)
    func cancelFollowUpNotifications(for baseID: UUID)
    func clearDeliveredNotifications(for id: UUID)

    func cancelDailyCheckInNotification(for medicationID: UUID, on date: Date)
    func cancelPendingDailyCheckInNotifications(for medicationID: UUID)

    func rescheduleReminderOccurrenceIfPending(
        medication: Medication,
        time: Date,
        baseID: UUID,
        reminderIndex: Int?,
        referenceDate: Date
    )

    func removeUntrackedMedicationReminders(
        for medicationID: UUID,
        preservingIdentifiers identifiersToKeep: Set<String>
    )

    func setApplicationBadge(count: Int)
    func fetchPendingMedicationReminders(completion: @escaping ([UNNotificationRequest]) -> Void)
    func fetchDeliveredMedicationReminders(completion: @escaping ([UNNotification]) -> Void)
    func clearDeliveredMedicationReminders()
    func purgeNotifications(excluding validMedicationIDs: Set<UUID>)
}

extension NotificationManager: NotificationManagerProtocol {}

extension NotificationManagerProtocol {
    func requestAuthorizationIfNeeded() {
        requestAuthorizationIfNeeded(completion: nil)
    }

    func scheduleOneTimeReminder(for medication: Medication, afterMinutes: Int) {
        scheduleOneTimeReminder(
            for: medication,
            afterMinutes: afterMinutes,
            sourceNotificationBaseID: nil,
            reminderIndex: nil,
            scheduledDoseDate: nil
        )
    }
}
