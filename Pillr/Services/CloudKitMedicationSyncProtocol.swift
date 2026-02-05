import Foundation
import CloudKit

protocol CloudKitMedicationSyncProtocol: AnyObject {
    func ensureSubscriptions()
    func fetchAllRecords(
        completion: @escaping (Result<(medications: [Medication], logs: [MedicationLog]), Error>) -> Void
    )
    func save(medication: Medication, completion: ((Result<CKRecord, Error>) -> Void)?)
    func save(
        log: MedicationLog,
        medication: Medication,
        completion: ((Result<CKRecord, Error>) -> Void)?
    )
    func markMedicationDeleted(_ medication: Medication, completion: ((Result<Void, Error>) -> Void)?)
    func markLogDeleted(_ log: MedicationLog, completion: ((Result<Void, Error>) -> Void)?)
}

extension CloudKitMedicationSync: CloudKitMedicationSyncProtocol {}

extension CloudKitMedicationSyncProtocol {
    func save(medication: Medication) {
        save(medication: medication, completion: nil)
    }

    func save(log: MedicationLog, medication: Medication) {
        save(log: log, medication: medication, completion: nil)
    }

    func markMedicationDeleted(_ medication: Medication) {
        markMedicationDeleted(medication, completion: nil)
    }

    func markLogDeleted(_ log: MedicationLog) {
        markLogDeleted(log, completion: nil)
    }
}
