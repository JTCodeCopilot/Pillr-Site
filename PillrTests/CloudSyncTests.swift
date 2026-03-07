import Foundation
import Testing
@testable import Pillr

@MainActor
struct CloudSyncTests {
    private func makeMedication(
        id: UUID = UUID(),
        name: String,
        updatedAt: Date,
        isDeleted: Bool = false
    ) -> Medication {
        Medication(
            id: id,
            name: name,
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: updatedAt,
            updatedAt: updatedAt,
            frequency: "As needed",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: updatedAt,
            reminderTimes: [],
            notes: nil,
            notificationID: nil,
            notificationIDs: [],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: false,
            isDeleted: isDeleted,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: updatedAt
        )
    }

    @Test
    func mergeCloudMedicationsKeepsMissingLocalsWhenSyncSnapshotIsIncomplete() async throws {
        clearPillrUserDefaults()
        UserSettings.shared.setPremiumStatus(false)
        UserSettings.shared.setCloudSyncPreference(true)

        let store = MedicationStore(isPreview: false)
        let now = makeDate(year: 2025, month: 1, day: 14, hour: 8, minute: 0)
        let med1 = makeMedication(name: "Local 1", updatedAt: now)
        let med2 = makeMedication(name: "Local 2", updatedAt: now)
        store.medications = [med1, med2]

        store._test_mergeCloudMedications([med1])
        await Task.yield()

        #expect(store.medications.contains(where: { $0.id == med1.id }) == true)
        #expect(store.medications.contains(where: { $0.id == med2.id }) == true)
        #expect(store._test_getDeletedMedicationIDs().contains(med2.id) == false)
    }

    @Test
    func mergeCloudMedicationsHonorsRemoteDeletions() async throws {
        clearPillrUserDefaults()
        UserSettings.shared.setCloudSyncPreference(true)

        let store = MedicationStore(isPreview: false)
        let now = makeDate(year: 2025, month: 1, day: 15, hour: 8, minute: 0)
        let med1 = makeMedication(name: "Local 1", updatedAt: now)
        store.medications = [med1]

        let deletedRemote = makeMedication(id: med1.id, name: "Local 1", updatedAt: now, isDeleted: true)
        store._test_mergeCloudMedications([deletedRemote])
        await Task.yield()

        #expect(store.medications.contains(where: { $0.id == med1.id }) == false)
        #expect(store._test_getDeletedMedicationIDs().contains(med1.id) == true)
    }

    @Test
    func shouldReplaceUsesNewestUpdatedAtForMedicationAndLog() async throws {
        let store = MedicationStore(isPreview: true)
        let earlier = makeDate(year: 2025, month: 1, day: 16, hour: 8, minute: 0)
        let later = makeDate(year: 2025, month: 1, day: 16, hour: 10, minute: 0)

        let local = makeMedication(name: "Local", updatedAt: earlier)
        let remote = makeMedication(id: local.id, name: "Remote", updatedAt: later)
        #expect(store._test_shouldReplace(local: local, with: remote) == true)

        let localLog = MedicationLog(
            medicationID: local.id,
            medicationName: local.name,
            takenAt: earlier,
            updatedAt: earlier
        )
        let remoteLog = MedicationLog(
            id: localLog.id,
            medicationID: local.id,
            medicationName: local.name,
            takenAt: earlier,
            updatedAt: later
        )
        #expect(store._test_shouldReplace(local: localLog, with: remoteLog) == true)
    }

    @Test
    func mergeCloudLogsReplacesAndRemovesDeleted() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)

        let medID = UUID()
        let logID = UUID()
        let earlier = makeDate(year: 2025, month: 1, day: 20, hour: 8, minute: 0)
        let later = makeDate(year: 2025, month: 1, day: 20, hour: 9, minute: 0)

        let local = MedicationLog(
            id: logID,
            medicationID: medID,
            medicationName: "Local",
            takenAt: earlier,
            updatedAt: earlier
        )
        store.logs = [local]

        let remoteNewer = MedicationLog(
            id: logID,
            medicationID: medID,
            medicationName: "Remote",
            takenAt: earlier,
            updatedAt: later
        )
        store._test_mergeCloudLogs([remoteNewer])
        await Task.yield()

        #expect(store.logs.first?.medicationName == "Remote")

        let remoteDeleted = MedicationLog(
            id: logID,
            medicationID: medID,
            medicationName: "Remote",
            takenAt: earlier,
            updatedAt: later.addingTimeInterval(60),
            isDeleted: true
        )
        store._test_mergeCloudLogs([remoteDeleted])
        await Task.yield()

        #expect(store.logs.isEmpty == true)
    }

    @Test
    func deletedMedicationIDsCanBeSetAndRead() async throws {
        let store = MedicationStore(isPreview: true)
        let ids: Set<UUID> = [UUID(), UUID()]

        store._test_setDeletedMedicationIDs(ids)
        #expect(store._test_getDeletedMedicationIDs() == ids)
    }
}
