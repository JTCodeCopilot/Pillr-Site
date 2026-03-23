import Foundation
import Testing
@testable import Pillr

@MainActor
struct NotificationFollowUpTests {
    @Test
    func trackNowCancelsOnlyCurrentFollowUpOccurrenceForLoggedMedication() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 1, hour: 8, minute: 0)
        let baseNotificationID = UUID()

        let medication = Medication(
            id: UUID(),
            name: "FollowUp Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: baseNotificationID,
            notificationIDs: [baseNotificationID],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: true,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let identifier = "\(baseNotificationID.uuidString)_20250201T0800"
        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString
        ]

        delegate._test_handleNotification(
            actionIdentifier: "TRACK_NOW_ACTION",
            userInfo: userInfo,
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(store.logs.count == 1)
        #expect(
            notificationManager.canceledFollowUpOccurrences.contains(where: { entry in
                entry.0 == baseNotificationID
            })
        )
        #expect(notificationManager.canceledFollowUps.contains(baseNotificationID) == false)
    }

    @Test
    func trackNowUsesReminderContextToCancelMatchingFollowUp() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 1, hour: 8, minute: 0)
        let followUpTime = Calendar.current.date(byAdding: .minute, value: 30, to: baseTime) ?? baseTime
        let baseNotificationID = UUID()

        let medication = Medication(
            id: UUID(),
            name: "FollowUp Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: baseNotificationID,
            notificationIDs: [baseNotificationID],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: true,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let identifier = "\(baseNotificationID.uuidString)_day_20250201"
        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString,
            "reminderBaseID": baseNotificationID.uuidString,
            "scheduledDoseAt": baseTime.timeIntervalSince1970,
            "reminderIndex": 0
        ]

        delegate._test_handleNotification(
            actionIdentifier: "TRACK_NOW_ACTION",
            userInfo: userInfo,
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(
            notificationManager.canceledFollowUpOccurrences.contains(where: { entry in
                entry.0 == baseNotificationID && entry.1 == followUpTime
            })
        )
    }

    @Test
    func duplicateTrackNowActionIsIgnored() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 1, hour: 8, minute: 0)
        let baseNotificationID = UUID()
        let medication = Medication(
            id: UUID(),
            name: "Idempotent Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: baseNotificationID,
            notificationIDs: [baseNotificationID],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: true,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )
        let identifier = "\(baseNotificationID.uuidString)_day_20250201"
        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString,
            "reminderIndex": 0,
            "scheduleDayKey": "20250201"
        ]

        delegate._test_handleNotification(
            actionIdentifier: "TRACK_NOW_ACTION",
            userInfo: userInfo,
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )
        delegate._test_handleNotification(
            actionIdentifier: "TRACK_NOW_ACTION",
            userInfo: userInfo,
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(store.logs.count == 1)
    }

    @Test
    func trackNowClearsStaleOverdueReminderCache() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let now = Date()
        let baseNotificationID = UUID()

        let medication = Medication(
            id: UUID(),
            name: "Cache Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: now,
            updatedAt: now,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: now,
            reminderTimes: [now],
            notes: nil,
            notificationID: baseNotificationID,
            notificationIDs: [baseNotificationID],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: true,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]
        store._test_setOverdueReminderNotificationIDs(["stale-overdue-id"])

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString,
            "reminderIndex": 0
        ]

        delegate._test_handleNotification(
            actionIdentifier: "TRACK_NOW_ACTION",
            userInfo: userInfo,
            notificationIdentifier: baseNotificationID.uuidString,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: now
        )

        #expect(store.logs.count == 1)
        #expect(store.overdueReminderNotificationIDs.isEmpty)
        #expect(notificationManager.badgeCounts.last == 0)
    }

    @Test
    func remindLaterSchedulesNewReminderAndCancelsExistingFollowUp() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 1, hour: 8, minute: 0)
        let baseNotificationID = UUID()

        let medication = Medication(
            id: UUID(),
            name: "FollowUp Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: baseNotificationID,
            notificationIDs: [baseNotificationID],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: true,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let identifier = "\(baseNotificationID.uuidString)_20250201T0800"
        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString,
            "reminderIndex": 0
        ]

        delegate._test_handleNotification(
            actionIdentifier: "REMIND_LATER",
            userInfo: userInfo,
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(notificationManager.scheduledOneTime.count == 1)
        #expect(notificationManager.scheduledOneTime.first?.1 == 30)
        #expect(notificationManager.scheduledOneTimeContext.first?.0 == baseNotificationID)
        #expect(notificationManager.scheduledOneTimeContext.first?.1 == 0)
        #expect(notificationManager.scheduledOneTimeContext.first?.2 == baseTime)
        #expect(notificationManager.canceledFollowUpOccurrences.contains(where: { $0.0 == baseNotificationID }) == true)
    }

    @Test
    func missingMedicationCancelsNotificationsAndResetsBadge() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let missingID = UUID()
        let baseTime = makeDate(year: 2025, month: 2, day: 2, hour: 8, minute: 0)

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let userInfo: [AnyHashable: Any] = [
            "medicationID": missingID.uuidString
        ]

        delegate._test_handleNotification(
            actionIdentifier: "TRACK_NOW_ACTION",
            userInfo: userInfo,
            notificationIdentifier: UUID().uuidString,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(notificationManager.canceledMedicationIDs.contains(missingID) == true)
        #expect(notificationManager.badgeCounts.last == 0)
    }

    @Test
    func notificationCheckInSetsContext() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 3, hour: 8, minute: 0)
        let medication = Medication(
            id: UUID(),
            name: "CheckIn Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .stimulant,
            isExtendedRelease: false,
            onsetMinutes: 30,
            durationMinutes: 240,
            effectsGoneMinutes: 360,
            enableDailyCheckIn: true,
            enableStimulantPhaseNotifications: true,
            dailyCheckInTime: baseTime,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: UUID(),
            notificationIDs: [UUID()],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: false,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString,
            "phase": "checkin"
        ]

        delegate._test_handleNotification(
            actionIdentifier: "DEFAULT_ACTION",
            userInfo: userInfo,
            notificationIdentifier: UUID().uuidString,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(store.dailyCheckInContext?.medication.id == medication.id)
        #expect(store.dailyCheckInContext?.entrySource == .notification)
    }

    @Test
    func notificationFadeCheckInSetsContextWithLogID() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 4, hour: 8, minute: 0)
        let logID = UUID()
        let medication = Medication(
            id: UUID(),
            name: "Fade Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .stimulant,
            isExtendedRelease: false,
            onsetMinutes: 30,
            durationMinutes: 240,
            effectsGoneMinutes: 360,
            enableDailyCheckIn: true,
            enableStimulantPhaseNotifications: true,
            dailyCheckInTime: baseTime,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: UUID(),
            notificationIDs: [UUID()],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: false,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        let userInfo: [AnyHashable: Any] = [
            "medicationID": medication.id.uuidString,
            "phase": "fade",
            "isDailyCheckIn": true,
            "logID": logID.uuidString
        ]

        delegate._test_handleNotification(
            actionIdentifier: "DEFAULT_ACTION",
            userInfo: userInfo,
            notificationIdentifier: UUID().uuidString,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(store.dailyCheckInContext?.medication.id == medication.id)
        #expect(store.dailyCheckInContext?.logID == logID)
        #expect(store.dailyCheckInContext?.entrySource == .notification)
    }

    @Test
    func unknownActionWithMedicationReminderHighlightsMedication() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 5, hour: 8, minute: 0)
        let medication = Medication(
            id: UUID(),
            name: "Highlight Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: UUID(),
            notificationIDs: [UUID()],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: false,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )

        delegate._test_handleNotification(
            actionIdentifier: "DEFAULT_ACTION",
            userInfo: ["medicationID": medication.id.uuidString],
            notificationIdentifier: UUID().uuidString,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        #expect(store.highlightedMedicationID == medication.id)
        #expect(store.notificationHighlightMedicationID == medication.id)
    }

    @Test
    func duplicateActionsWithDifferentScheduleKeysAreProcessedSeparately() async throws {
        clearPillrUserDefaults()

        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 2, day: 6, hour: 8, minute: 0)
        let baseNotificationID = UUID()
        let medication = Medication(
            id: UUID(),
            name: "Repeat Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: baseTime,
            updatedAt: baseTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            notificationID: baseNotificationID,
            notificationIDs: [baseNotificationID],
            pillCount: nil,
            pillsPerDose: 1,
            refillThreshold: nil,
            isSkipped: false,
            isOneTimeWithFollowUp: true,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
        store.medications = [medication]

        let delegate = NotificationDelegate(
            notificationManager: notificationManager,
            medicationStore: store
        )
        let identifier = "\(baseNotificationID.uuidString)_day_20250206"

        delegate._test_handleNotification(
            actionIdentifier: "REMIND_LATER",
            userInfo: [
                "medicationID": medication.id.uuidString,
                "reminderIndex": 0,
                "scheduleDayKey": "20250206"
            ],
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime
        )

        delegate._test_handleNotification(
            actionIdentifier: "REMIND_LATER",
            userInfo: [
                "medicationID": medication.id.uuidString,
                "reminderIndex": 0,
                "scheduleDayKey": "20250207"
            ],
            notificationIdentifier: identifier,
            categoryIdentifier: "MEDICATION_REMINDER",
            notificationDate: baseTime.addingTimeInterval(24 * 60 * 60)
        )

        #expect(notificationManager.scheduledOneTime.count == 2)
    }
}
