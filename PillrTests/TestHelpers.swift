import Foundation
@testable import Pillr

actor UserSettingsTestGate {
    func withExclusiveAccess<T>(_ body: () async throws -> T) async rethrows -> T {
        try await body()
    }
}

let userSettingsTestGate = UserSettingsTestGate()

func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0,
    calendar: Calendar = Calendar.current
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

func clearUserDefaults(keys: [String]) {
    let defaults = UserDefaults.standard
    for key in keys {
        defaults.removeObject(forKey: key)
    }
}

func clearPillrUserDefaults() {
    clearUserDefaults(keys: [
        "medicationsData",
        "medicationLogsData",
        "medicationsData_backup",
        "medicationLogsData_backup",
        "deletedMedicationIDs",
        "userName",
        "hasShownPrivacyNotice",
        "is_premium_user",
        "subscription_type",
        "seen_onboarding_stages",
        "hasSeenCabinetIntroOverlay",
        "hasSeenNotificationOnboardingPrompt",
        "has_completed_app_onboarding",
        "is_biometric_lock_enabled",
        "should_show_apple_health_data",
        "is_history_tab_enabled",
        "is_reflection_tab_enabled",
        "is_timeline_tab_enabled",
        "is_interaction_checker_shortcut_enabled",
        "custom_side_effects",
        "interactionHistoryData",
        "recentSearchesData",
        "deletedInteractionIDs",
        "apple_health_authorization_status",
        "apple_health_has_connected",
        "apple_health_last_steps",
        "apple_health_last_distance_miles",
        "apple_health_last_hourly_heart_rate"
    ])
}

func resetInteractionStoreState(_ store: InteractionStore) {
    store.clearHistory()
    store.clearRecentSearches()
    store.selectedSeverityFilter = nil
    store.sortOrder = .dateDescending
    store.searchResults = []
}
