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
    @Published private(set) var hourlyAverageHeartRate: Double?
    @Published private(set) var hasAnyPermission = false
    @Published private(set) var hasAllPermissions = false
    @Published private(set) var hasConnected = false
    @Published private(set) var authorizationError: String?
    @Published private(set) var hasDeniedPermission = false
    @Published private(set) var hasHeartRatePermission = false
    @Published private(set) var hasDeniedHeartRatePermission = false
    @Published private(set) var lastUpdated: Date?

    // MARK: - Private properties
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    static let authorizationStorageKey = "apple_health_authorization_status"
    static let hasConnectedStorageKey = "apple_health_has_connected"
    private static let lastStepsStorageKey = "apple_health_last_steps"
    private static let lastDistanceStorageKey = "apple_health_last_distance_miles"
    private static let lastHourlyHeartRateStorageKey = "apple_health_last_hourly_heart_rate"

    init() {
        if let cachedSteps = UserDefaults.standard.object(forKey: Self.lastStepsStorageKey) as? NSNumber {
            self.dailySteps = cachedSteps.intValue
        }
        if let cachedDistance = UserDefaults.standard.object(forKey: Self.lastDistanceStorageKey) as? NSNumber {
            self.dailyDistanceMiles = cachedDistance.doubleValue
        }
        if let cachedHeartRate = UserDefaults.standard.object(forKey: Self.lastHourlyHeartRateStorageKey) as? NSNumber {
            self.hourlyAverageHeartRate = cachedHeartRate.doubleValue
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
        if hasAnyPermission && !hasHeartRatePermission && !hasDeniedHeartRatePermission {
            Task { [weak self] in
                await self?.requestHeartRateAuthorizationIfNeeded()
            }
        }
    }

    private static let requiredIdentifiers: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .distanceWalkingRunning,
        .heartRate
    ]

    private var readQuantityTypes: [HKQuantityType] {
        Self.requiredIdentifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
    }

    private var readSampleTypes: Set<HKSampleType> {
        Set(readQuantityTypes)
    }

    private var heartRateSampleTypes: Set<HKSampleType> {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        return [heartRateType]
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
            let success = try await performAuthorization(readTypes: readSampleTypes)
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

    func requestHeartRateAuthorizationIfNeeded() async {
        guard isHealthDataAvailable else { return }
        updatePermissionState()
        guard !hasHeartRatePermission else { return }

        let heartRateTypes = heartRateSampleTypes
        guard !heartRateTypes.isEmpty else { return }

        authorizationError = nil
        do {
            let success = try await performAuthorization(readTypes: heartRateTypes)
            if success {
                persistConnectionStatus(true)
                hasHeartRatePermission = true
                hasDeniedHeartRatePermission = false
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
        let lastHourPredicate = lastHourPredicate()

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
        let heartRate = await fetchAverage(
            identifier: .heartRate,
            unit: HKUnit(from: "count/min"),
            predicate: lastHourPredicate
        )

        dailySteps = steps.map { Int($0.rounded(.down)) }
        dailyDistanceMiles = distance
        hourlyAverageHeartRate = heartRate
        lastUpdated = Date()
        if let stepsValue = dailySteps {
            UserDefaults.standard.set(stepsValue, forKey: Self.lastStepsStorageKey)
        }
        if let distanceValue = dailyDistanceMiles {
            UserDefaults.standard.set(distanceValue, forKey: Self.lastDistanceStorageKey)
        }
        if let heartRateValue = hourlyAverageHeartRate {
            UserDefaults.standard.set(heartRateValue, forKey: Self.lastHourlyHeartRateStorageKey)
        }
    }

    func refreshAuthorizationState() async {
        updatePermissionState()
        if hasAnyPermission && !hasHeartRatePermission && !hasDeniedHeartRatePermission {
            await requestHeartRateAuthorizationIfNeeded()
        }
        if hasAnyPermission || hasConnected {
            await refreshMetrics()
        }
    }

    // MARK: - Private helpers
    var hasMetricValues: Bool {
        dailySteps != nil || dailyDistanceMiles != nil || hourlyAverageHeartRate != nil
    }

    private func updatePermissionState() {
        let statuses = readQuantityTypes.map { healthStore.authorizationStatus(for: $0) }
        let hasAuthorized = statuses.contains { $0 == .sharingAuthorized }
        hasAnyPermission = hasAuthorized
        hasAllPermissions = !readQuantityTypes.isEmpty && statuses.allSatisfy { $0 == .sharingAuthorized }
        hasDeniedPermission = statuses.contains { $0 == .sharingDenied }
        let heartRateStatus = heartRateAuthorizationStatus()
        hasHeartRatePermission = heartRateStatus == .sharingAuthorized
        hasDeniedHeartRatePermission = heartRateStatus == .sharingDenied
        if hasAuthorized {
            persistConnectionStatus(true)
        } else if hasDeniedPermission {
            persistConnectionStatus(false)
        } else if hasConnected {
            // Keep prior authorization while HealthKit resolves its status on launch.
            hasAnyPermission = true
        }
    }

    private func heartRateAuthorizationStatus() -> HKAuthorizationStatus {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return .notDetermined
        }
        return healthStore.authorizationStatus(for: heartRateType)
    }

    private func todayPredicate() -> NSPredicate {
        let startOfDay = calendar.startOfDay(for: Date())
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
    }

    private func lastHourPredicate() -> NSPredicate {
        let endDate = Date()
        let startDate = calendar.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        return HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
    }

    private func performAuthorization(readTypes: Set<HKSampleType>) async throws -> Bool {
        guard !readTypes.isEmpty else {
            return false
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
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

    private func fetchAverage(
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
                options: .discreteAverage
            ) { _, statistics, error in
                if let _ = error {
                    continuation.resume(returning: nil)
                    return
                }

                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }
}
