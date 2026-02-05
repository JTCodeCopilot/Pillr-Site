import Foundation
import CloudKit

protocol CloudKitInteractionSyncProtocol: AnyObject {
    func ensureSubscriptions()
    func fetchInteractions(completion: @escaping (Result<[CloudInteractionRecord], Error>) -> Void)
    func save(interaction: DrugInteraction, completion: ((Result<CKRecord, Error>) -> Void)?)
    func markInteractionDeleted(_ interaction: DrugInteraction, completion: ((Result<Void, Error>) -> Void)?)
}

extension CloudKitMedicationSync: CloudKitInteractionSyncProtocol {}

extension CloudKitInteractionSyncProtocol {
    func save(interaction: DrugInteraction) {
        save(interaction: interaction, completion: nil)
    }

    func markInteractionDeleted(_ interaction: DrugInteraction) {
        markInteractionDeleted(interaction, completion: nil)
    }
}
