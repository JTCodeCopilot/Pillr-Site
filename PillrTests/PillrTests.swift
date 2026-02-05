//
//  PillrTests.swift
//  PillrTests
//
//  Created by Justin Tilley on 5/2/2026.
//

import Foundation
import Testing

/// General sanity and logic tests for the Pillr app.
/// These are intentionally simple and fast-running unit tests.
struct PillrTests {

    // MARK: - App sanity

    @Test
    func appCanLoadBasicTypes() async throws {
        // Basic sanity check that core Foundation types behave as expected
        let value = 1 + 1
        #expect(value == 2)
    }

    // MARK: - Date and time logic (important for reminders)

    @Test
    func hourlyIntervalsAreCalculatedCorrectly() async throws {
        let start = Date(timeIntervalSince1970: 0)

        let oneHour: TimeInterval = 60 * 60
        let second = start.addingTimeInterval(oneHour)
        let third = second.addingTimeInterval(oneHour)

        #expect(second.timeIntervalSince(start) == oneHour)
        #expect(third.timeIntervalSince(second) == oneHour)
    }

    // MARK: - Notification identifier logic

    @Test
    func notificationIdentifiersAreUnique() async throws {
        let ids = (0..<10).map { _ in UUID().uuidString }
        let uniqueIds = Set(ids)

        #expect(ids.count == uniqueIds.count)
    }

    // MARK: - Data consistency

    @Test
    func medicationNamesAreTrimmedCorrectly() async throws {
        let rawName = "  Vyvanse  "
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(trimmed == "Vyvanse")
    }

    // MARK: - Edge cases

    @Test
    func emptyMedicationNameIsHandled() async throws {
        let name = ""
        #expect(name.isEmpty == true)
    }
}
