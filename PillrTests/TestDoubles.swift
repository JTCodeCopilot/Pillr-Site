import Foundation
import UserNotifications
import CloudKit
@testable import Pillr

final class FakeNotificationManager: NotificationManagerProtocol {
    var badgeCountProvider: ((Date) -> Int)?

    private(set) var scheduledMultiple: [Medication] = []
    private(set) var scheduledSingle: [Medication] = []
    private(set) var canceledMultiple: [[UUID]] = []
    private(set) var canceledSingle: [UUID] = []
    private(set) var canceledFollowUps: [UUID] = []
    private(set) var canceledFollowUpOccurrences: [(UUID, Date)] = []
    private(set) var scheduledOneTime: [(Medication, Int)] = []
    private(set) var scheduledOneTimeContext: [(UUID?, Int?, Date?)] = []
    private(set) var rescheduledOccurrences: [(Medication, Date, UUID, Int?, Date)] = []
    var pendingMedicationReminderRequests: [UNNotificationRequest] = []
    private(set) var canceledMedicationIDs: [UUID] = []
    private(set) var badgeCounts: [Int] = []
    private(set) var removedUntracked: [(UUID, Set<String>)] = []
    private(set) var registered: [UUID] = []
    private(set) var updatedTracked: [Set<UUID>] = []

    func updateTrackedMedicationIDs(_ ids: Set<UUID>) {
        updatedTracked.append(ids)
    }

    func registerTrackedMedicationID(_ id: UUID) {
        registered.append(id)
    }

    func unregisterTrackedMedicationID(_ id: UUID) {}

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)?) {
        completion?(true)
    }

    func scheduleTestReminder(afterSeconds: TimeInterval, completion: ((Bool) -> Void)?) {
        completion?(true)
    }

    func scheduleNotification(for medication: Medication) -> UUID? {
        scheduledSingle.append(medication)
        return UUID()
    }

    func scheduleMultipleNotifications(for medication: Medication) -> [UUID] {
        scheduledMultiple.append(medication)
        return medication.reminderTimes.map { _ in UUID() }
    }

    func scheduleOneTimeReminder(
        for medication: Medication,
        afterMinutes: Int,
        sourceNotificationBaseID: UUID?,
        reminderIndex: Int?,
        scheduledDoseDate: Date?
    ) {
        scheduledOneTime.append((medication, afterMinutes))
        scheduledOneTimeContext.append((sourceNotificationBaseID, reminderIndex, scheduledDoseDate))
    }

    func scheduleStimulantPhaseNotifications(for medication: Medication, doseTime: Date, logID: UUID) {}

    func scheduleDailyCheckInReminder(for medication: Medication, referenceDate: Date) {}

    func cancelNotification(with id: UUID) {
        canceledSingle.append(id)
    }

    func cancelMultipleNotifications(ids: [UUID]) {
        canceledMultiple.append(ids)
    }

    func cancelMedicationNotifications(for medicationID: UUID) {
        canceledMedicationIDs.append(medicationID)
    }
    func cancelReminderOccurrence(for baseID: UUID, on date: Date) {}
    func cancelFollowUpNotification(for baseID: UUID, on date: Date) {
        canceledFollowUpOccurrences.append((baseID, date))
    }
    func cancelFollowUpNotifications(for baseID: UUID) {
        canceledFollowUps.append(baseID)
    }
    func clearDeliveredNotifications(for id: UUID) {}
    func cancelDailyCheckInNotification(for medicationID: UUID, on date: Date) {}
    func cancelPendingDailyCheckInNotifications(for medicationID: UUID) {}

    func rescheduleReminderOccurrenceIfPending(
        medication: Medication,
        time: Date,
        baseID: UUID,
        reminderIndex: Int?,
        referenceDate: Date
    ) {
        rescheduledOccurrences.append((medication, time, baseID, reminderIndex, referenceDate))
    }

    func removeUntrackedMedicationReminders(
        for medicationID: UUID,
        preservingIdentifiers identifiersToKeep: Set<String>
    ) {
        removedUntracked.append((medicationID, identifiersToKeep))
    }

    func setApplicationBadge(count: Int) {
        badgeCounts.append(count)
    }
    func fetchPendingMedicationReminders(completion: @escaping ([UNNotificationRequest]) -> Void) {
        completion(pendingMedicationReminderRequests)
    }
    func fetchDeliveredMedicationReminders(completion: @escaping ([UNNotification]) -> Void) {
        completion([])
    }
    func clearDeliveredMedicationReminders() {}
    func purgeNotifications(excluding validMedicationIDs: Set<UUID>) {}
}

final class FakeCloudKitSync: CloudKitMedicationSyncProtocol {
    private(set) var savedMedications: [Medication] = []
    private(set) var savedLogs: [MedicationLog] = []

    func ensureSubscriptions() {}

    func fetchAllRecords(
        completion: @escaping (Result<(medications: [Medication], logs: [MedicationLog]), Error>) -> Void
    ) {
        completion(.success((medications: [], logs: [])))
    }

    func save(medication: Medication, completion: ((Result<CKRecord, Error>) -> Void)?) {
        savedMedications.append(medication)
        completion?(.failure(NSError(domain: "FakeCloudKit", code: 0)))
    }

    func save(
        log: MedicationLog,
        medication: Medication,
        completion: ((Result<CKRecord, Error>) -> Void)?
    ) {
        savedLogs.append(log)
        completion?(.failure(NSError(domain: "FakeCloudKit", code: 0)))
    }

    func markMedicationDeleted(_ medication: Medication, completion: ((Result<Void, Error>) -> Void)?) {
        completion?(.success(()))
    }

    func markLogDeleted(_ log: MedicationLog, completion: ((Result<Void, Error>) -> Void)?) {
        completion?(.success(()))
    }
}
