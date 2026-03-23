import Foundation
import Testing
@testable import Pillr

@MainActor
struct MedicationStoreTests {
    private func makeMedication(
        name: String = "TestMed",
        time: Date,
        reminderTimes: [Date] = [],
        frequency: String = "Once daily",
        pillCount: Int? = nil,
        pillsPerDose: Int = 1,
        refillThreshold: Int? = nil,
        enableDailyCheckIn: Bool = false,
        dailyCheckInTime: Date? = nil,
        createdAt: Date? = nil
    ) -> Medication {
        Medication(
            name: name,
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: createdAt ?? time,
            updatedAt: time,
            frequency: frequency,
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: enableDailyCheckIn,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: dailyCheckInTime,
            timeToTake: time,
            reminderTimes: reminderTimes,
            notes: nil,
            notificationID: UUID(),
            notificationIDs: reminderTimes.map { _ in UUID() },
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold,
            isSkipped: false,
            isOneTimeWithFollowUp: false,
            isDeleted: false,
            logReferenceID: nil,
            logEntryID: nil,
            cloudLastModified: nil
        )
    }

    @Test
    func addMedicationFreeTierLimitsAndStripsPremiumFields() async throws {
        clearPillrUserDefaults()
        UserSettings.shared.setPremiumStatus(false)
        UserSettings.shared.setSubscriptionType(nil)

        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 1, hour: 8, minute: 0)

        for i in 0..<UserSettings.maxFreeMedications {
            let added = store.addMedication(
                name: "Med \(i)",
                dosage: "10",
                dosageUnit: "mg",
                iconName: "pill",
                frequency: "Twice daily",
                timeToTake: baseTime,
                reminderTimes: [baseTime],
                notes: nil,
                enableNotification: false,
                pillCount: 20,
                pillsPerDose: 2,
                refillThreshold: 5,
                isOneTimeWithFollowUp: false,
                medicationType: .other,
                isExtendedRelease: false,
                onsetMinutes: nil,
                durationMinutes: nil,
                effectsGoneMinutes: nil,
                enableDailyCheckIn: true,
                enableStimulantPhaseNotifications: false,
                dailyCheckInTime: baseTime
            )
            #expect(added == true)
        }

        let blocked = store.addMedication(
            name: "Over Limit",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            frequency: "Twice daily",
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            enableNotification: false,
            pillCount: 20,
            pillsPerDose: 2,
            refillThreshold: 5,
            isOneTimeWithFollowUp: false,
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: true,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: baseTime
        )

        #expect(blocked == false)

        guard let stored = store.medications.first else {
            #expect(Bool(false))
            return
        }

        #expect(stored.pillCount == nil)
        #expect(stored.pillsPerDose == 1)
        #expect(stored.refillThreshold == nil)
        #expect(stored.reminderTimes.isEmpty)
        #expect(stored.enableDailyCheckIn == false)
        #expect(stored.dailyCheckInTime == nil)
        #expect(stored.frequency == "Once daily")
    }

    @Test
    func addMedicationPremiumKeepsFields() async throws {
        clearPillrUserDefaults()
        UserSettings.shared.setPremiumStatus(true)
        UserSettings.shared.setSubscriptionType("one-time-purchase")

        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 2, hour: 9, minute: 0)

        let added = store.addMedication(
            name: "Premium Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            frequency: "Twice daily",
            timeToTake: baseTime,
            reminderTimes: [baseTime],
            notes: nil,
            enableNotification: false,
            pillCount: 20,
            pillsPerDose: 2,
            refillThreshold: 5,
            isOneTimeWithFollowUp: false,
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: true,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: baseTime
        )

        #expect(added == true)
        guard let stored = store.medications.first else {
            #expect(Bool(false))
            return
        }

        #expect(stored.pillCount == 20)
        #expect(stored.pillsPerDose == 2)
        #expect(stored.refillThreshold == 5)
        #expect(stored.reminderTimes.count == 1)
        #expect(stored.enableDailyCheckIn == true)
        #expect(stored.dailyCheckInTime != nil)
        #expect(stored.frequency == "Twice daily")
    }

    @Test
    func badgeCountShowsOverdueAndClearsWhenLogged() async throws {
        clearPillrUserDefaults()
        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let calendar = Calendar.current
        let now = Date()
        let reminderBase = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        let reminderComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderBase)
        let reminderTime = calendar.date(from: reminderComponents) ?? reminderBase
        let med = Medication(
            name: "Overdue Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: reminderTime,
            updatedAt: reminderTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: reminderTime,
            reminderTimes: [reminderTime],
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
        store.medications = [med]

        store.resetBadgeIfNeeded()
        #expect(notificationManager.badgeCounts.last == 1)

        _ = store.logMedicationTaken(
            medication: med,
            actualTime: now,
            notes: nil,
            skipped: false,
            reminderIndex: 0
        )
        store.resetBadgeIfNeeded()
        #expect(notificationManager.badgeCounts.last == 0)
    }

    @Test
    func badgeCountClearsWhenSkipped() async throws {
        clearPillrUserDefaults()
        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let calendar = Calendar.current
        let now = Date()
        let reminderBase = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        let reminderComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderBase)
        let reminderTime = calendar.date(from: reminderComponents) ?? reminderBase
        let med = Medication(
            name: "Skipped Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: reminderTime,
            updatedAt: reminderTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: reminderTime,
            reminderTimes: [reminderTime],
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
        store.medications = [med]

        store.resetBadgeIfNeeded()
        #expect(notificationManager.badgeCounts.last == 1)

        _ = store.logMedicationTaken(
            medication: med,
            actualTime: now,
            notes: nil,
            skipped: true,
            reminderIndex: 0
        )
        store.resetBadgeIfNeeded()
        #expect(notificationManager.badgeCounts.last == 0)
    }

    @Test
    func reconcileNotificationSchedulesRepairsMissingPendingReminder() async throws {
        clearPillrUserDefaults()
        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let referenceDate = makeDate(year: 2025, month: 2, day: 10, hour: 7, minute: 0)
        let reminderTime = makeDate(year: 2025, month: 2, day: 10, hour: 8, minute: 0)
        let baseID = UUID()
        let med = Medication(
            name: "Repair Med",
            dosage: "10",
            dosageUnit: "mg",
            iconName: "pill",
            createdAt: reminderTime,
            updatedAt: reminderTime,
            frequency: "Once daily",
            medicationType: .other,
            isExtendedRelease: false,
            onsetMinutes: nil,
            durationMinutes: nil,
            effectsGoneMinutes: nil,
            enableDailyCheckIn: false,
            enableStimulantPhaseNotifications: false,
            dailyCheckInTime: nil,
            timeToTake: reminderTime,
            reminderTimes: [reminderTime],
            notes: nil,
            notificationID: nil,
            notificationIDs: [baseID],
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
        store.medications = [med]

        store._test_reconcileNotificationSchedules(withPendingRequests: [], referenceDate: referenceDate)

        #expect(notificationManager.rescheduledOccurrences.count == 1)
        #expect(notificationManager.rescheduledOccurrences.first?.2 == baseID)
        #expect(notificationManager.rescheduledOccurrences.first?.3 == 0)
    }

    @Test
    func logMedicationTakenPreventsDuplicateSingleDoseLogs() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 3, hour: 8, minute: 0)
        var med = makeMedication(time: baseTime)
        med.notificationID = UUID()
        med.reminderNotificationsEnabled = true
        store.medications = [med]

        let first = store.logMedicationTaken(
            medication: med,
            actualTime: baseTime,
            notes: nil,
            skipped: false
        )
        #expect(first != nil)

        let second = store.logMedicationTaken(
            medication: med,
            actualTime: baseTime.addingTimeInterval(60 * 60),
            notes: nil,
            skipped: false
        )
        #expect(second == nil)
        #expect(store.logs.count == 1)
    }

    @Test
    func legacyLogMedicationIDRepairReconnectsMislinkedCabinetLogs() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 2, day: 1, hour: 9, minute: 0)
        let medication = makeMedication(name: "Repair Target", time: baseTime, frequency: "As needed")
        store.medications = [medication]

        let sourceLog = MedicationLog(
            id: UUID(),
            medicationID: medication.id,
            medicationName: medication.name,
            takenAt: baseTime
        )
        let mislinkedLog = MedicationLog(
            id: UUID(),
            medicationID: sourceLog.id, // Legacy bug: points to another log id instead of medication id
            medicationName: medication.name,
            takenAt: baseTime.addingTimeInterval(1800)
        )
        store.logs = [mislinkedLog, sourceLog]

        store._test_runLegacyLogMedicationIDRepair(markCompleteWhenNoChanges: true)

        let repaired = store.logs.first(where: { $0.id == mislinkedLog.id })
        #expect(repaired?.medicationID == medication.id)
    }

    @Test
    func logMedicationTakenPreventsDuplicateReminderIndexLogs() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let morning = makeDate(year: 2025, month: 1, day: 4, hour: 8, minute: 0)
        let evening = makeDate(year: 2025, month: 1, day: 4, hour: 20, minute: 0)
        var med = makeMedication(time: morning, reminderTimes: [morning, evening])
        med.notificationIDs = [UUID(), UUID()]
        med.reminderNotificationsEnabled = true
        store.medications = [med]

        let first = store.logMedicationTaken(
            medication: med,
            actualTime: morning,
            notes: nil,
            skipped: false,
            reminderIndex: 0
        )
        #expect(first != nil)

        let second = store.logMedicationTaken(
            medication: med,
            actualTime: morning.addingTimeInterval(60),
            notes: nil,
            skipped: false,
            reminderIndex: 0
        )
        #expect(second == nil)
        #expect(store.logs.count == 1)
    }

    @Test
    func pillCountNeverDropsBelowZeroAndReplacesLogs() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 5, hour: 8, minute: 0)
        let med = makeMedication(time: baseTime, pillCount: 1, pillsPerDose: 2)
        store.medications = [med]

        _ = store.logMedicationTaken(
            medication: med,
            actualTime: baseTime,
            notes: nil,
            skipped: false
        )
        #expect(store.medications.first?.pillCount == 0)

        _ = store.logMedicationTaken(
            medication: med,
            actualTime: baseTime,
            notes: nil,
            skipped: true
        )
        #expect(store.medications.first?.pillCount == 2)
    }

    @Test
    func inferReminderIndexUsesNearestAvailableTime() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let morning = makeDate(year: 2025, month: 1, day: 6, hour: 8, minute: 0)
        let evening = makeDate(year: 2025, month: 1, day: 6, hour: 20, minute: 0)
        let actual = makeDate(year: 2025, month: 1, day: 6, hour: 20, minute: 10)

        let med = makeMedication(time: morning, reminderTimes: [morning, evening])
        store.medications = [med]
        store.logs = [
            MedicationLog(
                medicationID: med.id,
                medicationName: med.name,
                takenAt: morning.addingTimeInterval(5 * 60),
                pillsConsumed: 1,
                reminderIndex: 0
            )
        ]

        let index = store._test_inferReminderIndexIfNeeded(
            medication: med,
            actualTime: actual
        )
        #expect(index == 1)
    }

    @Test
    func resolvedTakenReminderIndicesAssignsNilIndexLogs() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let morning = makeDate(year: 2025, month: 1, day: 7, hour: 8, minute: 0)
        let evening = makeDate(year: 2025, month: 1, day: 7, hour: 20, minute: 0)
        let med = makeMedication(time: morning, reminderTimes: [morning, evening])
        let dayStart = Calendar.current.startOfDay(for: morning)

        let logs = [
            MedicationLog(
                medicationID: med.id,
                medicationName: med.name,
                takenAt: morning.addingTimeInterval(5 * 60),
                pillsConsumed: 1,
                reminderIndex: nil
            )
        ]

        let indices = store._test_resolvedTakenReminderIndices(
            medication: med,
            dayStart: dayStart,
            logs: logs
        )
        #expect(indices.contains(0) == true)
    }

    @Test
    func scheduledReminderTimeMovesToNextDayIfCreatedAfterTime() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let day = makeDate(year: 2025, month: 1, day: 8, hour: 0, minute: 0)
        let scheduledTime = makeDate(year: 2025, month: 1, day: 8, hour: 8, minute: 0)
        let createdAt = makeDate(year: 2025, month: 1, day: 8, hour: 10, minute: 0)
        let med = makeMedication(time: scheduledTime, createdAt: createdAt)

        let next = store._test_scheduledReminderTime(
            medication: med,
            reminderIndex: nil,
            dayStart: Calendar.current.startOfDay(for: day),
            referenceDate: day
        )

        let expected = Calendar.current.date(byAdding: .day, value: 1, to: scheduledTime)
        #expect(expected != nil)
        if let expected {
            #expect(next == expected)
        }
    }

    @Test
    func scheduledTimeForTodayHandlesAsNeededAndNearest() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let morning = makeDate(year: 2025, month: 1, day: 9, hour: 8, minute: 0)
        let evening = makeDate(year: 2025, month: 1, day: 9, hour: 20, minute: 0)
        let actual = makeDate(year: 2025, month: 1, day: 9, hour: 19, minute: 30)

        let asNeeded = makeMedication(time: morning, reminderTimes: [], frequency: "As needed")
        let nilScheduled = store._test_scheduledTimeForToday(
            medication: asNeeded,
            actualTime: actual,
            reminderIndex: nil
        )
        #expect(nilScheduled == nil)

        let med = makeMedication(time: morning, reminderTimes: [morning, evening])
        let nearest = store._test_scheduledTimeForToday(
            medication: med,
            actualTime: actual,
            reminderIndex: nil
        )
        #expect(nearest == evening)
    }

    @Test
    func overdueSnapshotsRespectTakenAndUpcomingReminders() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let eight = makeDate(year: 2025, month: 1, day: 10, hour: 8, minute: 0)
        let one = makeDate(year: 2025, month: 1, day: 10, hour: 13, minute: 0)
        let twenty = makeDate(year: 2025, month: 1, day: 10, hour: 20, minute: 0)
        let reference = makeDate(year: 2025, month: 1, day: 10, hour: 12, minute: 0)

        let med1 = makeMedication(name: "A", time: eight, reminderTimes: [])
        let med2 = makeMedication(name: "B", time: one, reminderTimes: [])
        let med3 = makeMedication(name: "C", time: eight, reminderTimes: [eight, twenty])

        store.medications = [med1, med2, med3]
        store.logs = [
            MedicationLog(
                medicationID: med3.id,
                medicationName: med3.name,
                takenAt: eight.addingTimeInterval(5 * 60),
                pillsConsumed: 1,
                reminderIndex: 0
            )
        ]

        let overdueCount = store._test_overdueReminderCountSnapshot(referenceDate: reference)
        let overdueIDs = store._test_overdueMedicationIDsSnapshot(referenceDate: reference)
        #expect(overdueCount == 1)
        #expect(overdueIDs.contains(med1.id))
        #expect(overdueIDs.contains(med2.id) == false)
    }

    @Test
    func dailyCheckInOverdueCustomTimeRequiresDoseBeforeTrigger() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let doseTime = makeDate(year: 2025, month: 1, day: 11, hour: 9, minute: 0)
        let checkInTime = makeDate(year: 2025, month: 1, day: 11, hour: 18, minute: 0)
        let reference = makeDate(year: 2025, month: 1, day: 11, hour: 19, minute: 0)

        let med = makeMedication(
            time: doseTime,
            enableDailyCheckIn: true,
            dailyCheckInTime: checkInTime
        )
        store.medications = [med]
        store.logs = [
            MedicationLog(
                medicationID: med.id,
                medicationName: med.name,
                takenAt: doseTime,
                pillsConsumed: 1,
                reminderIndex: nil
            )
        ]

        #expect(store.isDailyCheckInOverdue(for: med, referenceDate: reference) == true)

        let createdLate = makeMedication(
            time: doseTime,
            enableDailyCheckIn: true,
            dailyCheckInTime: checkInTime,
            createdAt: makeDate(year: 2025, month: 1, day: 11, hour: 20, minute: 0)
        )
        store.medications = [createdLate]
        #expect(store.isDailyCheckInOverdue(for: createdLate, referenceDate: reference) == false)
    }

    @Test
    func undoLogActionRestoresLogsAndPillCounts() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 12, hour: 8, minute: 0)
        let med = makeMedication(time: baseTime, pillCount: 10, pillsPerDose: 2)
        store.medications = [med]

        let action = store.logMedicationTaken(
            medication: med,
            actualTime: baseTime,
            notes: nil,
            skipped: false
        )
        #expect(action != nil)
        #expect(store.logs.count == 1)
        #expect(store.medications.first?.pillCount == 8)

        if let action {
            store.undoLogAction(action)
        }

        #expect(store.logs.isEmpty)
        #expect(store.medications.first?.pillCount == 10)
    }

    @Test
    func removeDoseLogRestoresPillCount() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 13, hour: 8, minute: 0)
        let med = makeMedication(time: baseTime, pillCount: 10, pillsPerDose: 2)
        store.medications = [med]

        _ = store.logMedicationTaken(
            medication: med,
            actualTime: baseTime,
            notes: nil,
            skipped: false
        )
        #expect(store.medications.first?.pillCount == 8)
        guard let log = store.logs.first else {
            #expect(Bool(false))
            return
        }

        store.removeDoseLog(log)
        #expect(store.medications.first?.pillCount == 10)
    }

    @Test
    func toggleSkipNeedsRefillAndRemainingCountReflectMedicationState() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 14, hour: 8, minute: 0)
        let med = makeMedication(time: baseTime, pillCount: 4, pillsPerDose: 1, refillThreshold: 5)
        store.medications = [med]

        #expect(store.getRemainingPillCount(for: med.id) == 4)
        #expect(store.needsRefill(medicationID: med.id) == true)
        #expect(store.medications.first?.isSkipped == false)

        store.toggleSkipStatus(for: med.id)
        #expect(store.medications.first?.isSkipped == true)
    }

    @Test
    func hideLogFromMyMedsAndDeleteMedicationClearState() async throws {
        clearPillrUserDefaults()
        let notificationManager = FakeNotificationManager()
        let cloudSync = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: true,
            notificationManager: notificationManager,
            cloudSync: cloudSync
        )

        let baseTime = makeDate(year: 2025, month: 1, day: 15, hour: 8, minute: 0)
        let med = makeMedication(time: baseTime)
        let log = MedicationLog(
            medicationID: med.id,
            medicationName: med.name,
            takenAt: baseTime,
            pillsConsumed: 1
        )

        store.medications = [med]
        store.logs = [log]
        store.dailyCheckInContext = DailyCheckInContext(medication: med, entrySource: .notification)
        store.highlightedMedicationID = med.id
        store.notificationHighlightMedicationID = med.id

        store.hideLogFromMyMeds(log)
        #expect(store.logs.first?.hiddenFromMyMeds == true)

        store.deleteMedication(med)
        #expect(store.medications.first?.isDeleted == true)
        #expect(store.dailyCheckInContext == nil)
        #expect(store.highlightedMedicationID == nil)
        #expect(store.notificationHighlightMedicationID == nil)
        #expect(notificationManager.canceledMedicationIDs.contains(med.id) == true)
    }

    @Test
    func pendingCheckInsIgnoreDuplicatesAndMissingMedications() async throws {
        clearPillrUserDefaults()
        let store = MedicationStore(isPreview: true)
        let baseTime = makeDate(year: 2025, month: 1, day: 16, hour: 8, minute: 0)
        let med = makeMedication(time: baseTime, enableDailyCheckIn: true, dailyCheckInTime: baseTime)
        store.medications = [med]

        let existing = DailyCheckInContext(medication: med, entrySource: .notification)
        let missingMedication = makeMedication(name: "Missing", time: baseTime)
        let missing = DailyCheckInContext(medication: missingMedication, entrySource: .notification)

        store.enqueuePendingCheckIns([
            .daily(existing),
            .daily(existing),
            .daily(missing)
        ])

        #expect(store.dailyCheckInContext?.medication.id == med.id)
        store.dailyCheckInContext = nil
        store.presentNextPendingCheckInIfNeeded()
        #expect(store.dailyCheckInContext == nil)
    }
}
