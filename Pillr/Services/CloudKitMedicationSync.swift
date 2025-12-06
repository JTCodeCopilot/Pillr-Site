import Foundation
import CloudKit

final class CloudKitMedicationSync {
    static let shared = CloudKitMedicationSync()

    private let database: CKDatabase

    private init() {
        self.database = CKContainer.default().privateCloudDatabase
    }

    private enum RecordType: String {
        case medication = "Medication"
        case medicationLog = "MedicationLog"
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
        static let isArchived = "isArchived"
        static let logReferenceID = "logReferenceID"
        static let logEntryID = "logEntryID"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"

        static let medicationReference = "medicationReference"
        static let medicationName = "medicationName"
        static let takenAt = "takenAt"
        static let skipped = "skipped"
        static let pillsConsumed = "pillsConsumed"
        static let reminderIndex = "reminderIndex"
        static let focusRating = "focusRating"
        static let sideEffectSeverity = "sideEffectSeverity"
        static let notesLog = "notes"
    }

    // MARK: - Public API

    func save(medication: Medication, completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        let record = medicationRecord(from: medication)
        record[Field.updatedAt] = Date() as CKRecordValue
        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(.failure(error))
                } else if let savedRecord = savedRecord {
                    completion?(.success(savedRecord))
                }
            }
        }
    }

    func deleteMedication(id: UUID, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let recordID = CKRecord.ID(recordName: id.uuidString)
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

    func save(log: MedicationLog, medication: Medication, completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        let record = medicationLogRecord(from: log, medication: medication)
        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(.failure(error))
                } else if let savedRecord = savedRecord {
                    completion?(.success(savedRecord))
                }
            }
        }
    }

    func delete(log: MedicationLog, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let recordID = CKRecord.ID(recordName: log.id.uuidString)
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
                logResults = records.compactMap { self.medicationLog(from: $0) }
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
        record[Field.isArchived] = medication.isArchived as CKRecordValue
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
        record[Field.takenAt] = log.takenAt as CKRecordValue
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
        if let focusRating = log.focusRating {
            record[Field.focusRating] = focusRating as CKRecordValue
        }
        if let sideEffectSeverity = log.sideEffectSeverity {
            record[Field.sideEffectSeverity] = sideEffectSeverity as CKRecordValue
        }
        let reference = CKRecord.Reference(recordID: CKRecord.ID(recordName: medication.id.uuidString), action: .none)
        record[Field.medicationReference] = reference
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
        let isArchived = record[Field.isArchived] as? Bool ?? false
        let enableDailyCheckIn = record[Field.enableDailyCheckIn] as? Bool ?? false
        let enableStimulantPhaseNotifications = record[Field.enableStimulantPhaseNotifications] as? Bool ?? false
        let isExtendedRelease = record[Field.isExtendedRelease] as? Bool ?? false
        let onsetMinutes = record[Field.onsetMinutes] as? Int
        let durationMinutes = record[Field.durationMinutes] as? Int
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
        let cloudLastModified = record.modificationDate ?? record.creationDate

        return Medication(
            id: id,
            name: name,
            dosage: dosage,
            dosageUnit: dosageUnit,
            iconName: iconName,
            createdAt: createdAt,
            frequency: frequency,
            medicationType: medicationType,
            isExtendedRelease: isExtendedRelease,
            onsetMinutes: onsetMinutes,
            durationMinutes: durationMinutes,
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
            isArchived: isArchived,
            logReferenceID: logReferenceID,
            logEntryID: logEntryID,
            cloudLastModified: cloudLastModified
        )
    }

    private func medicationLog(from record: CKRecord) -> MedicationLog? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let medicationReference = record[Field.medicationReference] as? CKRecord.Reference,
              let medicationID = UUID(uuidString: medicationReference.recordID.recordName),
              let medicationName = record[Field.medicationName] as? String,
              let takenAt = record[Field.takenAt] as? Date else {
            return nil
        }

        let notes = record[Field.notesLog] as? String
        let skipped = record[Field.skipped] as? Bool ?? false
        let pillsConsumed = record[Field.pillsConsumed] as? Int
        let reminderIndex = record[Field.reminderIndex] as? Int
        let focusRating = record[Field.focusRating] as? Int
        let sideEffectSeverity = record[Field.sideEffectSeverity] as? Int

        return MedicationLog(
            id: id,
            medicationID: medicationID,
            medicationName: medicationName,
            takenAt: takenAt,
            notes: notes,
            skipped: skipped,
            pillsConsumed: pillsConsumed,
            reminderIndex: reminderIndex,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity
        )
    }
}
