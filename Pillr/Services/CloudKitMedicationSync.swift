import Foundation
import CloudKit
import UIKit

final class CloudKitMedicationSync {
    static let shared = CloudKitMedicationSync()

    private let database: CKDatabase
    private let subscriptionID = "pillr-private-medication-changes"

    private init() {
        self.database = CKContainer.default().privateCloudDatabase
    }

    private enum RecordType: String {
        case medication = "Medication"
        case medicationLog = "MedicationLog"
        case drugInteraction = "DrugInteraction"
    }

    private struct Field {
        static let name = "name"
        static let dosage = "dosage"
        static let dosageUnit = "dosageUnit"
        static let iconName = "iconName"
        static let frequency = "frequency"
        static let medicationType = "medicationType"
        static let isExtendedRelease = "isExtendedRelease"
        static let onsetMinutes = "onsetMinutes"
        static let durationMinutes = "durationMinutes"
        static let effectsGoneMinutes = "effectsGoneMinutes"
        static let enableDailyCheckIn = "enableDailyCheckIn"
        static let enableStimulantPhaseNotifications = "enableStimulantPhaseNotifications"
        static let dailyCheckInTime = "dailyCheckInTime"
        static let timeToTake = "timeToTake"
        static let reminderTimes = "reminderTimes"
        static let scheduledReminderTimes = "scheduledReminderTimes"
        static let notes = "notes"
        static let pillCount = "pillCount"
        static let pillsPerDose = "pillsPerDose"
        static let refillThreshold = "refillThreshold"
        static let isSkipped = "isSkipped"
        static let isOneTimeWithFollowUp = "isOneTimeWithFollowUp"
        static let isDeleted = "isDeleted"
        static let logReferenceID = "logReferenceID"
        static let logEntryID = "logEntryID"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"

        static let medicationReference = "medicationReference"
        static let medicationID = "medicationID"
        static let medicationId = "medicationId"
        static let medicationName = "medicationName"
        static let takenAt = "takenAt"
        static let logUpdatedAt = "updatedAt"
        static let logIsDeleted = "isDeleted"
        static let skipped = "skipped"
        static let pillsConsumed = "pillsConsumed"
        static let reminderIndex = "reminderIndex"
        static let feelingRating = "feelingRating"
        static let focusRating = "focusRating"
        static let sideEffectSeverity = "sideEffectSeverity"
        static let reflectionSummary = "reflectionSummary"
        static let isDailyCheckIn = "isDailyCheckIn"
        static let notesLog = "notes"
        static let hiddenFromMyMeds = "hiddenFromMyMeds"
        static let medicationDosageText = "medicationDosageText"
        static let medicationIconName = "medicationIconName"
        static let medicationReminderCount = "medicationReminderCount"

        static let interactionDrugA = "drugA"
        static let interactionDrugB = "drugB"
        static let interactionSeverity = "severity"
        static let interactionDescription = "interactionDescription"
        static let interactionRecommendedAction = "interactionRecommendedAction"
        static let interactionTimestamp = "timestamp"
    }

    // MARK: - Public API

    func save(medication: Medication, completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        let record = medicationRecord(from: medication)
        let updatedAt = medication.updatedAt ?? Date()
        record[Field.updatedAt] = updatedAt as CKRecordValue
        if medication.isDeleted {
            saveForce(record: record, completion: completion)
        } else {
            saveWithConflictResolution(record: record, completion: completion)
        }
    }


    func save(log: MedicationLog, medication: Medication, completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        let record = medicationLogRecord(from: log, medication: medication)
        record[Field.logUpdatedAt] = (log.updatedAt ?? Date()) as CKRecordValue
        if log.isDeleted {
            saveForce(record: record, completion: completion)
        } else {
            saveWithConflictResolution(record: record, completion: completion)
        }
    }

    func delete(log: MedicationLog, completion: ((Result<Void, Error>) -> Void)? = nil) {
        markLogDeleted(log, completion: completion)
    }

    func deleteMedication(withID medicationID: UUID, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let recordID = CKRecord.ID(recordName: medicationID.uuidString)
        database.delete(withRecordID: recordID) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(.failure(error))
                } else {
                    completion?(.success(()))
                }
            }
        }
    }

    func save(interaction: DrugInteraction, completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        let record = interactionRecord(from: interaction, isDeleted: false)
        record[Field.updatedAt] = interaction.timestamp as CKRecordValue
        saveWithConflictResolution(record: record, completion: completion)
    }

    func markInteractionDeleted(_ interaction: DrugInteraction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let record = interactionRecord(from: interaction, isDeleted: true)
        record[Field.updatedAt] = Date() as CKRecordValue
        saveForce(record: record) { result in
            switch result {
            case .success:
                completion?(.success(()))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    func markMedicationDeleted(_ medication: Medication, completion: ((Result<Void, Error>) -> Void)? = nil) {
        var tombstone = medication
        tombstone.isDeleted = true
        tombstone.updatedAt = Date()
        save(medication: tombstone) { result in
            switch result {
            case .success:
                completion?(.success(()))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    func markLogDeleted(_ log: MedicationLog, completion: ((Result<Void, Error>) -> Void)? = nil) {
        var tombstone = log
        tombstone.isDeleted = true
        tombstone.updatedAt = Date()
        let medication = Medication(
            id: log.medicationID,
            name: log.medicationName,
            dosage: log.medicationDosageText,
            frequency: "Once daily",
            timeToTake: log.takenAt
        )
        save(log: tombstone, medication: medication) { result in
            switch result {
            case .success:
                completion?(.success(()))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    func fetchAllRecords(completion: @escaping (Result<(medications: [Medication], logs: [MedicationLog]), Error>) -> Void) {
        let dispatchGroup = DispatchGroup()

        var medicationResults: [Medication] = []
        var logResults: [MedicationLog] = []
        var fetchError: Error?

        dispatchGroup.enter()
        fetchRecords(of: .medication) { result in
            switch result {
            case let .success(records):
                medicationResults = records.compactMap { self.medication(from: $0) }
            case let .failure(error):
                fetchError = error
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        fetchRecords(of: .medicationLog) { result in
            switch result {
            case let .success(records):
                logResults = self.decodeMedicationLogs(records)
            case let .failure(error):
                fetchError = fetchError ?? error
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                completion(.success((medications: medicationResults, logs: logResults)))
            }
        }
    }

    func fetchInteractions(completion: @escaping (Result<[CloudInteractionRecord], Error>) -> Void) {
        fetchRecords(of: .drugInteraction) { result in
            switch result {
            case let .success(records):
                let interactions = records.compactMap { self.interaction(from: $0) }
                completion(.success(interactions))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func ensureSubscriptions() {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        database.save(subscription) { _, error in
            if let error = error as? CKError, error.code == .serverRejectedRequest {
                return
            }
            if let error = error as? CKError, error.code == .unknownItem {
                return
            }
            if let error = error {
                print("CloudKit subscription error: \(error)")
            }
        }
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard notification?.subscriptionID == subscriptionID else {
            completion(.noData)
            return
        }
        completion(.newData)
    }

    // MARK: - Helpers

    private func fetchRecords(of type: RecordType, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: type.rawValue, predicate: predicate)
        var collected: [CKRecord] = []

        let operation = CKQueryOperation(query: query)
        operation.recordFetchedBlock = { record in
            collected.append(record)
        }
        operation.queryCompletionBlock = { cursor, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            if let cursor = cursor {
                self.continueFetching(with: cursor, accumulated: collected, completion: completion)
            } else {
                DispatchQueue.main.async {
                    completion(.success(collected))
                }
            }
        }

        database.add(operation)
    }

    private func continueFetching(with cursor: CKQueryOperation.Cursor, accumulated: [CKRecord], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        var collected = accumulated
        let operation = CKQueryOperation(cursor: cursor)
        operation.recordFetchedBlock = { record in
            collected.append(record)
        }
        operation.queryCompletionBlock = { nextCursor, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            if let nextCursor {
                self.continueFetching(with: nextCursor, accumulated: collected, completion: completion)
            } else {
                DispatchQueue.main.async {
                    completion(.success(collected))
                }
            }
        }
        database.add(operation)
    }

    private func medicationRecord(from medication: Medication) -> CKRecord {
        let recordID = CKRecord.ID(recordName: medication.id.uuidString)
        let record = CKRecord(recordType: RecordType.medication.rawValue, recordID: recordID)

        record[Field.name] = medication.name as CKRecordValue
        record[Field.dosage] = medication.dosage as CKRecordValue
        record[Field.dosageUnit] = medication.dosageUnit as CKRecordValue
        record[Field.iconName] = medication.iconName as CKRecordValue
        record[Field.frequency] = medication.frequency as CKRecordValue
        record[Field.medicationType] = medication.medicationType.rawValue as CKRecordValue
        record[Field.isExtendedRelease] = medication.isExtendedRelease as CKRecordValue
        if let onsetMinutes = medication.onsetMinutes {
            record[Field.onsetMinutes] = NSNumber(value: onsetMinutes)
        }
        if let durationMinutes = medication.durationMinutes {
            record[Field.durationMinutes] = NSNumber(value: durationMinutes)
        }
        if let effectsGoneMinutes = medication.effectsGoneMinutes {
            record[Field.effectsGoneMinutes] = NSNumber(value: effectsGoneMinutes)
        }
        record[Field.enableDailyCheckIn] = medication.enableDailyCheckIn as CKRecordValue
        record[Field.enableStimulantPhaseNotifications] = medication.enableStimulantPhaseNotifications as CKRecordValue
        if let dailyCheckInTime = medication.dailyCheckInTime {
            record[Field.dailyCheckInTime] = dailyCheckInTime as CKRecordValue
        }
        record[Field.timeToTake] = medication.timeToTake as CKRecordValue

        if !medication.reminderTimes.isEmpty {
            record[Field.scheduledReminderTimes] = medication.reminderTimes as NSArray
        }
        if let notes = medication.notes {
            record[Field.notes] = notes as CKRecordValue
        }
        if let pillCount = medication.pillCount {
            record[Field.pillCount] = NSNumber(value: pillCount)
        }
        record[Field.pillsPerDose] = medication.pillsPerDose as CKRecordValue
        if let refillThreshold = medication.refillThreshold {
            record[Field.refillThreshold] = NSNumber(value: refillThreshold)
        }
        record[Field.isSkipped] = medication.isSkipped as CKRecordValue
        record[Field.isOneTimeWithFollowUp] = medication.isOneTimeWithFollowUp as CKRecordValue
        record[Field.isDeleted] = NSNumber(value: medication.isDeleted ? 1 : 0)
        if let logReferenceID = medication.logReferenceID {
            record[Field.logReferenceID] = logReferenceID.uuidString as CKRecordValue
        }
        if let logEntryID = medication.logEntryID {
            record[Field.logEntryID] = logEntryID.uuidString as CKRecordValue
        }
        if let createdAt = medication.createdAt {
            record[Field.createdAt] = createdAt as CKRecordValue
        }
        return record
    }

    private func medicationLogRecord(from log: MedicationLog, medication: Medication) -> CKRecord {
        let recordID = CKRecord.ID(recordName: log.id.uuidString)
        let record = CKRecord(recordType: RecordType.medicationLog.rawValue, recordID: recordID)
        record[Field.medicationName] = log.medicationName as CKRecordValue
        record[Field.medicationDosageText] = log.medicationDosageText as CKRecordValue
        record[Field.medicationIconName] = log.medicationIconName as CKRecordValue
        record[Field.medicationReminderCount] = log.medicationReminderCount as CKRecordValue
        record[Field.takenAt] = log.takenAt as CKRecordValue
        record[Field.logUpdatedAt] = (log.updatedAt ?? Date()) as CKRecordValue
        record[Field.logIsDeleted] = NSNumber(value: log.isDeleted ? 1 : 0)
        record[Field.hiddenFromMyMeds] = NSNumber(value: log.hiddenFromMyMeds)
        record[Field.skipped] = log.skipped as CKRecordValue
        if let notes = log.notes {
            record[Field.notesLog] = notes as CKRecordValue
        }
        if let pillsConsumed = log.pillsConsumed {
            record[Field.pillsConsumed] = pillsConsumed as CKRecordValue
        }
        if let reminderIndex = log.reminderIndex {
            record[Field.reminderIndex] = reminderIndex as CKRecordValue
        }
        if let feelingRating = log.feelingRating {
            record[Field.feelingRating] = feelingRating as CKRecordValue
        }
        if let focusRating = log.focusRating {
            record[Field.focusRating] = focusRating as CKRecordValue
        }
        if let sideEffectSeverity = log.sideEffectSeverity {
            record[Field.sideEffectSeverity] = sideEffectSeverity as CKRecordValue
        }
        if let reflectionSummary = log.reflectionSummary {
            record[Field.reflectionSummary] = reflectionSummary as CKRecordValue
        }
        record[Field.isDailyCheckIn] = log.isDailyCheckIn as CKRecordValue
        record[Field.medicationID] = medication.id.uuidString as CKRecordValue
        let reference = CKRecord.Reference(recordID: CKRecord.ID(recordName: medication.id.uuidString), action: .none)
        record[Field.medicationReference] = reference
        return record
    }

    private func interactionRecord(from interaction: DrugInteraction, isDeleted: Bool) -> CKRecord {
        let recordID = CKRecord.ID(recordName: interaction.id.uuidString)
        let record = CKRecord(recordType: RecordType.drugInteraction.rawValue, recordID: recordID)
        record[Field.interactionDrugA] = interaction.drugA as CKRecordValue
        record[Field.interactionDrugB] = interaction.drugB as CKRecordValue
        record[Field.interactionSeverity] = interaction.severity.rawValue as CKRecordValue
        record[Field.interactionDescription] = interaction.description as CKRecordValue
        record[Field.interactionRecommendedAction] = interaction.recommendedAction as CKRecordValue
        record[Field.interactionTimestamp] = interaction.timestamp as CKRecordValue
        record[Field.isDeleted] = NSNumber(value: isDeleted ? 1 : 0)
        return record
    }

    private func medication(from record: CKRecord) -> Medication? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let name = record[Field.name] as? String,
              let dosage = record[Field.dosage] as? String,
              let frequency = record[Field.frequency] as? String,
              let timeToTake = record[Field.timeToTake] as? Date else {
            return nil
        }

        let dosageUnit = record[Field.dosageUnit] as? String ?? "mg"
        let iconName = record[Field.iconName] as? String ?? "pill"
        let medicationTypeString = record[Field.medicationType] as? String ?? MedicationType.other.rawValue
        let medicationType = MedicationType(rawValue: medicationTypeString) ?? .other

        let reminderTimes: [Date]
        if let list = record[Field.scheduledReminderTimes] as? [Date] {
            reminderTimes = list
        } else if let single = record[Field.reminderTimes] as? Date {
            reminderTimes = [single]
        } else {
            reminderTimes = []
        }
        let notes = record[Field.notes] as? String
        let pillCount = record[Field.pillCount] as? Int
        let pillsPerDose = record[Field.pillsPerDose] as? Int ?? 1
        let refillThreshold = record[Field.refillThreshold] as? Int
        let isSkipped = record[Field.isSkipped] as? Bool ?? false
        let isOneTimeWithFollowUp = record[Field.isOneTimeWithFollowUp] as? Bool ?? false
        let isDeleted: Bool
        if let number = record[Field.isDeleted] as? NSNumber {
            isDeleted = number.boolValue
        } else if let boolValue = record[Field.isDeleted] as? Bool {
            isDeleted = boolValue
        } else {
            isDeleted = false
        }
        let enableDailyCheckIn = record[Field.enableDailyCheckIn] as? Bool ?? false
        let enableStimulantPhaseNotifications = record[Field.enableStimulantPhaseNotifications] as? Bool ?? false
        let isExtendedRelease = record[Field.isExtendedRelease] as? Bool ?? false
        let onsetMinutes = record[Field.onsetMinutes] as? Int
        let durationMinutes = record[Field.durationMinutes] as? Int
        let effectsGoneMinutes = record[Field.effectsGoneMinutes] as? Int
        let dailyCheckInTime = record[Field.dailyCheckInTime] as? Date

        let logReferenceID: UUID?
        if let string = record[Field.logReferenceID] as? String {
            logReferenceID = UUID(uuidString: string)
        } else {
            logReferenceID = nil
        }

        let logEntryID: UUID?
        if let string = record[Field.logEntryID] as? String {
            logEntryID = UUID(uuidString: string)
        } else {
            logEntryID = nil
        }

        let createdAt = record[Field.createdAt] as? Date ?? record.creationDate
        let updatedAt = record[Field.updatedAt] as? Date ?? record.modificationDate
        let cloudLastModified = record.modificationDate ?? record.creationDate

        return Medication(
            id: id,
            name: name,
            dosage: dosage,
            dosageUnit: dosageUnit,
            iconName: iconName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            frequency: frequency,
            medicationType: medicationType,
            isExtendedRelease: isExtendedRelease,
            onsetMinutes: onsetMinutes,
            durationMinutes: durationMinutes,
            effectsGoneMinutes: effectsGoneMinutes,
            enableDailyCheckIn: enableDailyCheckIn,
            enableStimulantPhaseNotifications: enableStimulantPhaseNotifications,
            dailyCheckInTime: dailyCheckInTime,
            timeToTake: timeToTake,
            reminderTimes: reminderTimes,
            notes: notes,
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold,
            isSkipped: isSkipped,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp,
            isDeleted: isDeleted,
            logReferenceID: logReferenceID,
            logEntryID: logEntryID,
            cloudLastModified: cloudLastModified
        )
    }

    private func medicationLog(from record: CKRecord) -> MedicationLog? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let medicationName = (record[Field.medicationName] as? String ?? record[Field.name] as? String),
              let takenAt = record[Field.takenAt] as? Date else {
            return nil
        }

        let medicationID: UUID? = {
            if let medicationReference = record[Field.medicationReference] as? CKRecord.Reference,
               let uuid = UUID(uuidString: medicationReference.recordID.recordName) {
                return uuid
            }
            if let value = record[Field.medicationID] as? String, let uuid = UUID(uuidString: value) {
                return uuid
            }
            if let value = record[Field.medicationId] as? String, let uuid = UUID(uuidString: value) {
                return uuid
            }
            return nil
        }()

        guard let medicationID else {
            return nil
        }

        let notes = record[Field.notesLog] as? String
        let skipped = record[Field.skipped] as? Bool ?? false
        let updatedAt = record[Field.logUpdatedAt] as? Date ?? record.modificationDate
        let isDeleted: Bool
        if let number = record[Field.logIsDeleted] as? NSNumber {
            isDeleted = number.boolValue
        } else if let boolValue = record[Field.logIsDeleted] as? Bool {
            isDeleted = boolValue
        } else {
            isDeleted = false
        }
        let pillsConsumed = record[Field.pillsConsumed] as? Int
        let reminderIndex = record[Field.reminderIndex] as? Int
        let feelingRating = record[Field.feelingRating] as? Int
        let focusRating = record[Field.focusRating] as? Int
        let sideEffectSeverity = record[Field.sideEffectSeverity] as? Int
        let reflectionSummary = record[Field.reflectionSummary] as? String
        let isDailyCheckIn = record[Field.isDailyCheckIn] as? Bool ?? false
        let hiddenFromMyMeds = record[Field.hiddenFromMyMeds] as? Bool ?? false
        let medicationDosageText = record[Field.medicationDosageText] as? String ?? ""
        let medicationIconName = record[Field.medicationIconName] as? String ?? "pill"
        let medicationReminderCount = record[Field.medicationReminderCount] as? Int ?? 0

        return MedicationLog(
            id: id,
            medicationID: medicationID,
            medicationName: medicationName,
            takenAt: takenAt,
            updatedAt: updatedAt,
            notes: notes,
            skipped: skipped,
            isDailyCheckIn: isDailyCheckIn,
            isDeleted: isDeleted,
            pillsConsumed: pillsConsumed,
            reminderIndex: reminderIndex,
            feelingRating: feelingRating,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity,
            reflectionSummary: reflectionSummary,
            hiddenFromMyMeds: hiddenFromMyMeds,
            medicationDosageText: medicationDosageText,
            medicationIconName: medicationIconName,
            medicationReminderCount: medicationReminderCount
        )
    }

    private func decodeMedicationLogs(_ records: [CKRecord]) -> [MedicationLog] {
        var decoded: [MedicationLog] = []
        decoded.reserveCapacity(records.count)
        var dropped = 0

        for record in records {
            if let log = medicationLog(from: record) {
                decoded.append(log)
            } else {
                dropped += 1
            }
        }

        if dropped > 0 {
            print("CloudKit: dropped \(dropped) MedicationLog record(s) during decode; decoded \(decoded.count) of \(records.count).")
        }

        return decoded
    }

    private func interaction(from record: CKRecord) -> CloudInteractionRecord? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let drugA = record[Field.interactionDrugA] as? String,
              let drugB = record[Field.interactionDrugB] as? String,
              let severityRaw = record[Field.interactionSeverity] as? String,
              let description = record[Field.interactionDescription] as? String,
              let recommendedAction = record[Field.interactionRecommendedAction] as? String,
              let timestamp = record[Field.interactionTimestamp] as? Date else {
            return nil
        }

        let severity = DrugInteraction.InteractionSeverity(rawValue: severityRaw) ?? .unknown
        let isDeleted: Bool
        if let number = record[Field.isDeleted] as? NSNumber {
            isDeleted = number.boolValue
        } else if let boolValue = record[Field.isDeleted] as? Bool {
            isDeleted = boolValue
        } else {
            isDeleted = false
        }
        let updatedAt = record[Field.updatedAt] as? Date ?? record.modificationDate

        let interaction = DrugInteraction(
            id: id,
            drugA: drugA,
            drugB: drugB,
            severity: severity,
            description: description,
            recommendedAction: recommendedAction,
            timestamp: timestamp
        )

        return CloudInteractionRecord(interaction: interaction, isDeleted: isDeleted, updatedAt: updatedAt)
    }

    private func saveWithConflictResolution(
        record: CKRecord,
        completion: ((Result<CKRecord, Error>) -> Void)? = nil
    ) {
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.modifyRecordsCompletionBlock = { [weak self] savedRecords, _, error in
            if let error = error as? CKError,
               error.code == .serverRecordChanged,
               let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
               let clientRecord = error.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord,
               let ancestorRecord = error.userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord,
               let resolved = self?.resolveConflict(
                server: serverRecord,
                client: clientRecord,
                ancestor: ancestorRecord
               ) {
                let retryOperation = CKModifyRecordsOperation(recordsToSave: [resolved], recordIDsToDelete: nil)
                retryOperation.savePolicy = .changedKeys
                retryOperation.modifyRecordsCompletionBlock = { retrySaved, _, retryError in
                    DispatchQueue.main.async {
                        if let retryError {
                            completion?(.failure(retryError))
                        } else if let record = retrySaved?.first {
                            completion?(.success(record))
                        }
                    }
                }
                self?.database.add(retryOperation)
                return
            }

            DispatchQueue.main.async {
                if let error {
                    completion?(.failure(error))
                } else if let record = savedRecords?.first {
                    completion?(.success(record))
                }
            }
        }
        database.add(operation)
    }

    private func resolveConflict(
        server: CKRecord,
        client: CKRecord,
        ancestor: CKRecord
    ) -> CKRecord {
        let serverUpdatedAt = server[Field.updatedAt] as? Date
        let clientUpdatedAt = client[Field.updatedAt] as? Date

        if let clientDate = clientUpdatedAt, let serverDate = serverUpdatedAt {
            return clientDate >= serverDate ? client : server
        }

        if let clientDate = clientUpdatedAt {
            return clientDate >= (serverUpdatedAt ?? clientDate) ? client : server
        }

        if let serverDate = serverUpdatedAt {
            return serverDate >= (clientUpdatedAt ?? serverDate) ? server : client
        }

        return client
    }

    private func saveForce(record: CKRecord, completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsCompletionBlock = { [weak self] savedRecords, _, error in
            if let error = error as? CKError,
               error.code == .serverRecordChanged,
               let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
               let clientRecord = error.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord,
               let ancestorRecord = error.userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord,
               let resolved = self?.resolveConflict(
                server: serverRecord,
                client: clientRecord,
                ancestor: ancestorRecord
               ) {
                let retryOperation = CKModifyRecordsOperation(recordsToSave: [resolved], recordIDsToDelete: nil)
                retryOperation.savePolicy = .changedKeys
                retryOperation.modifyRecordsCompletionBlock = { retrySaved, _, retryError in
                    DispatchQueue.main.async {
                        if let retryError {
                            completion?(.failure(retryError))
                        } else if let record = retrySaved?.first {
                            completion?(.success(record))
                        }
                    }
                }
                self?.database.add(retryOperation)
                return
            }

            DispatchQueue.main.async {
                if let error {
                    completion?(.failure(error))
                } else if let record = savedRecords?.first {
                    completion?(.success(record))
                }
            }
        }
        database.add(operation)
    }
}
