//
//  HealthKitManager.swift
//  Pillr
//
//  Created by Codex on 2025-05-??.
//

import Foundation
import HealthKit
import UIKit

@MainActor
final class HealthKitManager: ObservableObject {
    // MARK: - Published state
    @Published private(set) var dailySteps: Int?
    @Published private(set) var dailyDistanceMiles: Double?
    @Published private(set) var hasAnyPermission = false
    @Published private(set) var hasAllPermissions = false
    @Published private(set) var hasConnected = false
    @Published private(set) var authorizationError: String?
    @Published private(set) var hasDeniedPermission = false
    @Published private(set) var lastUpdated: Date?

    // MARK: - Private properties
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    static let authorizationStorageKey = "apple_health_authorization_status"
    static let hasConnectedStorageKey = "apple_health_has_connected"
    private static let lastStepsStorageKey = "apple_health_last_steps"
    private static let lastDistanceStorageKey = "apple_health_last_distance_miles"

    init() {
        if let cachedSteps = UserDefaults.standard.object(forKey: Self.lastStepsStorageKey) as? NSNumber {
            self.dailySteps = cachedSteps.intValue
        }
        if let cachedDistance = UserDefaults.standard.object(forKey: Self.lastDistanceStorageKey) as? NSNumber {
            self.dailyDistanceMiles = cachedDistance.doubleValue
        }
        let storedConnection = UserDefaults.standard.object(forKey: Self.hasConnectedStorageKey) as? Bool
        let legacyConnection = UserDefaults.standard.object(forKey: Self.authorizationStorageKey) as? Bool
        let connected = storedConnection ?? legacyConnection ?? false
        self.hasConnected = connected
        self.hasAnyPermission = connected
        updatePermissionState()
        if hasAnyPermission || hasConnected {
            Task { [weak self] in
                await self?.refreshAuthorizationState()
            }
        }
    }

    private static let requiredIdentifiers: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .distanceWalkingRunning
    ]

    private var readQuantityTypes: [HKQuantityType] {
        Self.requiredIdentifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
    }

    private var readSampleTypes: Set<HKSampleType> {
        Set(readQuantityTypes)
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Public helpers
    func requestAuthorizationIfNeeded() async {
        guard isHealthDataAvailable else {
            hasAnyPermission = false
            hasAllPermissions = false
            persistConnectionStatus(false)
            return
        }

        updatePermissionState()
        guard !hasAllPermissions else { return }
        guard !readSampleTypes.isEmpty else { return }

        authorizationError = nil
        do {
            let success = try await performAuthorization()
            if success {
                persistConnectionStatus(true)
                hasAnyPermission = true
                hasDeniedPermission = false
                await refreshMetrics()
            } else {
                updatePermissionState()
            }
        } catch {
            authorizationError = error.localizedDescription
            updatePermissionState()
        }
    }

    func refreshMetrics() async {
        guard isHealthDataAvailable else { return }
        updatePermissionState()

        let predicate = todayPredicate()

        authorizationError = nil
        let steps = await fetchSum(
            identifier: .stepCount,
            unit: HKUnit.count(),
            predicate: predicate
        )
        let distance = await fetchSum(
            identifier: .distanceWalkingRunning,
            unit: HKUnit.mile(),
            predicate: predicate
        )

        dailySteps = steps.map { Int($0.rounded(.down)) }
        dailyDistanceMiles = distance
        lastUpdated = Date()
        if let stepsValue = dailySteps {
            UserDefaults.standard.set(stepsValue, forKey: Self.lastStepsStorageKey)
        }
        if let distanceValue = dailyDistanceMiles {
            UserDefaults.standard.set(distanceValue, forKey: Self.lastDistanceStorageKey)
        }
    }

    func refreshAuthorizationState() async {
        updatePermissionState()
        if hasAnyPermission || hasConnected {
            await refreshMetrics()
        }
    }

    // MARK: - Private helpers
    var hasMetricValues: Bool {
        dailySteps != nil || dailyDistanceMiles != nil
    }

    private func updatePermissionState() {
        let statuses = readQuantityTypes.map { healthStore.authorizationStatus(for: $0) }
        let hasAuthorized = statuses.contains { $0 == .sharingAuthorized }
        hasAnyPermission = hasAuthorized
        hasAllPermissions = !readQuantityTypes.isEmpty && statuses.allSatisfy { $0 == .sharingAuthorized }
        hasDeniedPermission = statuses.contains { $0 == .sharingDenied }
        if hasAuthorized {
            persistConnectionStatus(true)
        } else if hasDeniedPermission {
            persistConnectionStatus(false)
        } else if hasConnected {
            // Keep prior authorization while HealthKit resolves its status on launch.
            hasAnyPermission = true
        }
    }

    private func todayPredicate() -> NSPredicate {
        let startOfDay = calendar.startOfDay(for: Date())
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
    }

    private func performAuthorization() async throws -> Bool {
        guard !readSampleTypes.isEmpty else {
            return false
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readSampleTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func openHealthSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }

    private func persistConnectionStatus(_ connected: Bool) {
        hasConnected = connected
        UserDefaults.standard.set(connected, forKey: Self.hasConnectedStorageKey)
        UserDefaults.standard.set(connected, forKey: Self.authorizationStorageKey)
    }

    private func fetchSum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let _ = error {
                    continuation.resume(returning: nil)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }
}
