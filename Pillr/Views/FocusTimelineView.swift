import SwiftUI

fileprivate enum FocusTimelineCardPalette {
    static let background = Color(hex: "#59655B")
    static let secondaryTint = Color(hex: "#424C43")
    static let divider = Color(hex: "#8C988E")
    static let titleText = Color(hex: "#F1F3F0")
    static let secondaryText = Color(hex: "#D6DBD3")
    static let timeText = Color(hex: "#E8ECE6")
}

struct FocusTimelineView: View {
    @EnvironmentObject var store: MedicationStore
    let isModal: Bool
    @Environment(\.dismiss) var dismiss
    
    enum DoseStatus {
        case pending
        case logged(Date)
        case skipped(Date)
    }
    
    struct FocusWindow: Identifiable {
        let id = UUID()
        let medication: Medication
        let doseIndex: Int
        let doseTime: Date
        let onsetTime: Date
        let fadeTime: Date
        let status: DoseStatus
        let scheduledDoseTime: Date?
    }

    struct FocusWindowGroup: Identifiable {
        let id: UUID
        let medication: Medication
        let windows: [FocusWindow]
    }

    fileprivate struct FocusSegment: Identifiable {
        let id = UUID()
        let start: Date
        let end: Date
        let activeMedicationCount: Int
    }

    fileprivate struct FocusPlannerCard: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
        let accent: Color
    }
    
    private var focusWindows: [FocusWindow] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var windows: [FocusWindow] = []
        let todaysLogs = todaysLogsByMedication
        let allLogs = todaysAllLogsByMedication
        
        for medication in store.activeMedications where medication.hasStimulantTiming {
            guard let onsetMinutes = medication.onsetMinutes,
                  let durationMinutes = medication.durationMinutes else { continue }
            
            let isAsNeededWithoutReminder = medication.frequency == "As needed" && medication.reminderTimes.isEmpty
            
            if isAsNeededWithoutReminder {
                // For ADHD medications that are "As needed" without reminders,
                // build focus windows only from doses actually logged today.
                let todaysLogs = store.logs.filter { log in
                    !log.skipped &&
                    log.isDoseLog &&
                    log.medicationID == medication.id &&
                    calendar.isDate(log.takenAt, inSameDayAs: today)
                }
                
                for (index, log) in todaysLogs.enumerated() {
                    let base = log.takenAt
                    
                    guard let onset = calendar.date(byAdding: .minute, value: onsetMinutes, to: base),
                          let fade = calendar.date(byAdding: .minute, value: durationMinutes, to: base) else { continue }
                    
                    // Only keep windows that intersect today
                    if fade > today {
                        let status: DoseStatus = .logged(base)
                        windows.append(
                            FocusWindow(
                                medication: medication,
                                doseIndex: index,
                                doseTime: base,
                                onsetTime: onset,
                                fadeTime: fade,
                                status: status,
                                scheduledDoseTime: nil
                            )
                        )
                    }
                }
            } else {
                // For scheduled ADHD medications, derive windows from their reminder times.
                let times = medication.reminderTimes.isEmpty ? [medication.timeToTake] : medication.reminderTimes
                let scheduledBases: [Date] = times.compactMap { rawTime in
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: rawTime)
                    return calendar.date(
                        bySettingHour: timeComponents.hour ?? 8,
                        minute: timeComponents.minute ?? 0,
                        second: 0,
                        of: today
                    )
                }

                guard !scheduledBases.isEmpty else { continue }

                let matchingLogs = todaysLogs[medication.id] ?? []
                let statusLogs = allLogs[medication.id] ?? []
                let actualAssignments = matchLogsToScheduledTimes(
                    scheduledTimes: scheduledBases,
                    logs: matchingLogs
                )
                let statusAssignments = matchLogsToScheduledTimes(
                    scheduledTimes: scheduledBases,
                    logs: statusLogs
                )

                for (index, scheduledBase) in scheduledBases.enumerated() {
                    let adjustedBase = actualAssignments[index]?.takenAt ?? scheduledBase
                    let status: DoseStatus = {
                        if let log = statusAssignments[index] {
                            return log.skipped ? .skipped(log.takenAt) : .logged(log.takenAt)
                        }
                        return .pending
                    }()

                    guard let adjustedOnset = calendar.date(byAdding: .minute, value: onsetMinutes, to: adjustedBase),
                          let adjustedFade = calendar.date(byAdding: .minute, value: durationMinutes, to: adjustedBase) else { continue }

                    if adjustedFade > today {
                        windows.append(
                            FocusWindow(
                                medication: medication,
                                doseIndex: index,
                                doseTime: adjustedBase,
                                onsetTime: adjustedOnset,
                                fadeTime: adjustedFade,
                                status: status,
                                scheduledDoseTime: scheduledBase
                            )
                        )
                    }
                }
            }
        }
        
        return windows.sorted { $0.onsetTime < $1.onsetTime }
    }

    private var medicationDisplayOrder: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: store.activeMedications.enumerated().map { ($0.element.id, $0.offset) })
    }

    private var focusWindowGroups: [FocusWindowGroup] {
        let grouped = Dictionary(grouping: focusWindows, by: { $0.medication.id })

        return grouped.values.map { group in
            let sortedGroup = group.sorted { first, second in
                if first.doseIndex == second.doseIndex {
                    let firstTime = first.scheduledDoseTime ?? first.doseTime
                    let secondTime = second.scheduledDoseTime ?? second.doseTime
                    return firstTime < secondTime
                }
                return first.doseIndex < second.doseIndex
            }
            return FocusWindowGroup(
                id: sortedGroup.first?.medication.id ?? UUID(),
                medication: sortedGroup.first?.medication ?? group[0].medication,
                windows: sortedGroup
            )
        }
        .sorted { first, second in
            let firstOrder = medicationDisplayOrder[first.medication.id] ?? Int.max
            let secondOrder = medicationDisplayOrder[second.medication.id] ?? Int.max
            if firstOrder == secondOrder {
                let firstTime = first.windows.first?.doseTime ?? .distantPast
                let secondTime = second.windows.first?.doseTime ?? .distantPast
                return firstTime < secondTime
            }
            return firstOrder < secondOrder
        }
    }
    
    private var hasWindows: Bool {
        !focusWindows.isEmpty
    }

    private var planningWindows: [FocusWindow] {
        focusWindows.filter {
            if case .skipped = $0.status {
                return false
            }
            return true
        }
    }

    private var focusSegments: [FocusSegment] {
        let sortedBoundaries = Array(
            Set(planningWindows.flatMap { [$0.onsetTime, $0.fadeTime] })
        ).sorted()

        guard sortedBoundaries.count > 1 else { return [] }

        var segments: [FocusSegment] = []

        for index in 0..<(sortedBoundaries.count - 1) {
            let start = sortedBoundaries[index]
            let end = sortedBoundaries[index + 1]
            guard end > start else { continue }

            let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            let activeCount = planningWindows.filter { window in
                window.onsetTime <= midpoint && midpoint < window.fadeTime
            }.count

            guard activeCount > 0 else { continue }

            segments.append(
                FocusSegment(
                    start: start,
                    end: end,
                    activeMedicationCount: activeCount
                )
            )
        }

        return segments
    }

    private var bestFocusSegment: FocusSegment? {
        focusSegments.max { first, second in
            if first.activeMedicationCount != second.activeMedicationCount {
                return first.activeMedicationCount < second.activeMedicationCount
            }

            let firstDuration = first.end.timeIntervalSince(first.start)
            let secondDuration = second.end.timeIntervalSince(second.start)
            if firstDuration != secondDuration {
                return firstDuration < secondDuration
            }

            return first.start > second.start
        }
    }

    private var currentActiveWindowCount: Int {
        let now = Date()
        return planningWindows.filter { window in
            window.onsetTime <= now && now <= window.fadeTime
        }.count
    }

    private var currentOpenWindowEnd: Date? {
        let now = Date()
        return planningWindows
            .filter { $0.onsetTime <= now && now <= $0.fadeTime }
            .map(\.fadeTime)
            .min()
    }

    private var nextUpcomingWindowStart: Date? {
        let now = Date()
        return planningWindows
            .map(\.onsetTime)
            .filter { $0 > now }
            .min()
    }

    private var overallFocusEnd: Date? {
        planningWindows.map(\.fadeTime).max()
    }

    private var plannerHeadline: String {
        let now = Date()

        if currentActiveWindowCount >= 2 {
            return "This looks like a strong focus stretch."
        }

        if currentActiveWindowCount == 1 {
            if let currentOpenWindowEnd, currentOpenWindowEnd.timeIntervalSince(now) <= 60 * 60 {
                return "You are in a focus window, but support may soften soon."
            }
            return "You are in a workable focus window now."
        }

        if let nextStart = nextUpcomingWindowStart {
            let minutesUntil = Int(nextStart.timeIntervalSince(now) / 60)
            if minutesUntil <= 60 {
                return "Your next focus window starts soon."
            }
            return "You have a lighter stretch before the next focus window."
        }

        return "No more focus windows are mapped for the rest of today."
    }

    private var plannerSubheadline: String {
        let now = Date()

        if let bestFocusSegment {
            if bestFocusSegment.start <= now && now <= bestFocusSegment.end {
                return "Good time for deep work, hard tasks, or anything that needs follow-through."
            }

            if bestFocusSegment.start > now {
                return "Use the lighter time before then for setup, messages, errands, or simple admin."
            }
        }

        if currentActiveWindowCount > 0 {
            return "Try to finish one meaningful task before the window fades."
        }

        if let nextUpcomingWindowStart {
            return "Aim to protect \(formatTime(nextUpcomingWindowStart)) onward for the work that matters most."
        }

        return "If you still need to log a dose, update it here so tomorrow's plan is more useful."
    }

    private var plannerCards: [FocusPlannerCard] {
        var cards: [FocusPlannerCard] = []

        if let bestFocusSegment {
            cards.append(
                FocusPlannerCard(
                    title: "Best Work Block",
                    value: timeRangeText(start: bestFocusSegment.start, end: bestFocusSegment.end),
                    detail: bestFocusSegment.activeMedicationCount > 1
                        ? "Likely your strongest stretch for deep work."
                        : "Likely your clearest stretch for focused work.",
                    accent: Color.pillrAccent
                )
            )
        }

        cards.append(
            FocusPlannerCard(
                title: "Right Now",
                value: currentStateValue,
                detail: currentStateDetail,
                accent: currentActiveWindowCount > 0 ? Color.pillrSecondary : Color(hex: "#F2B8A0")
            )
        )

        cards.append(
            FocusPlannerCard(
                title: "Next Shift",
                value: nextShiftValue,
                detail: nextShiftDetail,
                accent: Color.pillrToggleActive
            )
        )

        return cards
    }

    private var currentStateValue: String {
        if currentActiveWindowCount >= 2 {
            return "Strong focus"
        }
        if currentActiveWindowCount == 1 {
            return "Steady focus"
        }
        if nextUpcomingWindowStart != nil {
            return "Lighter stretch"
        }
        return "Day winding down"
    }

    private var currentStateDetail: String {
        if currentActiveWindowCount >= 2 {
            return "Best time to tackle your hardest task."
        }
        if currentActiveWindowCount == 1 {
            return "Good for normal work and staying on one thing."
        }
        if let nextUpcomingWindowStart {
            return "Keep this part of the day simple until \(formatTime(nextUpcomingWindowStart))."
        }
        return "Plan lower-pressure tasks or wrap up for the day."
    }

    private var nextShiftValue: String {
        let now = Date()

        if currentActiveWindowCount > 0, let currentOpenWindowEnd {
            return formatTime(currentOpenWindowEnd)
        }
        if let nextUpcomingWindowStart {
            return formatTime(nextUpcomingWindowStart)
        }
        if let overallFocusEnd, overallFocusEnd > now {
            return formatTime(overallFocusEnd)
        }
        return "No more today"
    }

    private var nextShiftDetail: String {
        if currentActiveWindowCount > 0 {
            return "Expect this current stretch to soften around then."
        }
        if nextUpcomingWindowStart != nil {
            return "A stronger focus window is expected to begin then."
        }
        return "Nothing else is mapped for the rest of today."
    }
    
    private var todaysLogsByMedication: [UUID: [MedicationLog]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todaysLogs = store.logs.filter { log in
            !log.skipped &&
            log.isDoseLog &&
            calendar.isDate(log.takenAt, inSameDayAs: today)
        }
        
        return Dictionary(grouping: todaysLogs, by: { $0.medicationID })
    }
    
    private var todaysAllLogsByMedication: [UUID: [MedicationLog]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todaysLogs = store.logs.filter { log in
            log.isDoseLog &&
            calendar.isDate(log.takenAt, inSameDayAs: today)
        }
        
        return Dictionary(grouping: todaysLogs, by: { $0.medicationID })
    }
    
    private var totalFocusMinutesToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return focusWindows.reduce(0) { partial, window in
            let start = max(window.onsetTime, today)
            let end = min(window.fadeTime, endOfDay)
            return partial + max(0, Int(end.timeIntervalSince(start) / 60))
        }
    }
    
    private var nextFocusWindow: FocusWindow? {
        let now = Date()
        return focusWindows.first { $0.fadeTime > now }
    }
    
    private var activeStimulantCount: Int {
        focusWindowGroups.count
    }
    
    private var upcomingWindowDescription: String {
        guard let nextWindow = nextFocusWindow else {
            return "No upcoming windows remaining today"
        }
        
        if nextWindow.onsetTime > Date() {
            return "Starts around \(formatTime(nextWindow.onsetTime))"
        }
        
        return "Fades around \(formatTime(nextWindow.fadeTime))"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func timeRangeText(start: Date, end: Date) -> String {
        "\(formatTime(start)) to \(formatTime(end))"
    }
    
    private func handleMedicationSelection(_ medication: Medication) {
        store.highlightedMedicationID = medication.id
        HapticManager.shared.lightImpact()
        
        if isModal {
            dismiss()
        } else {
            store.requestedMainTab = .meds
        }
    }
    
    private func matchLogsToScheduledTimes(
        scheduledTimes: [Date],
        logs: [MedicationLog]
    ) -> [Int: MedicationLog] {
        guard !scheduledTimes.isEmpty, !logs.isEmpty else { return [:] }

        var assignments: [Int: MedicationLog] = [:]
        var usedLogIDs = Set<UUID>()

        for log in logs {
            guard let index = log.reminderIndex,
                  scheduledTimes.indices.contains(index) else {
                continue
            }

            if let existing = assignments[index] {
                if log.takenAt > existing.takenAt {
                    assignments[index] = log
                }
            } else {
                assignments[index] = log
            }
        }

        for (_, log) in assignments {
            usedLogIDs.insert(log.id)
        }

        var unassignedLogs = logs.filter { !usedLogIDs.contains($0.id) }

        for index in scheduledTimes.indices where assignments[index] == nil {
            guard !unassignedLogs.isEmpty else { break }
            let scheduledTime = scheduledTimes[index]
            if let closest = unassignedLogs.enumerated().min(by: { lhs, rhs in
                abs(lhs.element.takenAt.timeIntervalSince(scheduledTime)) <
                    abs(rhs.element.takenAt.timeIntervalSince(scheduledTime))
            })?.offset {
                assignments[index] = unassignedLogs.remove(at: closest)
            }
        }

        return assignments
    }
    
    init(isModal: Bool = true) {
        self.isModal = isModal
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.pillrPrimary,
                        Color.pillrPrimary
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        
                        if hasWindows {
                            ForEach(Array(focusWindowGroups.enumerated()), id: \.element.id) { index, group in
                                FocusWindowRow(
                                    group: group,
                                    formatTime: formatTime,
                                    onSelectMedication: {
                                        handleMedicationSelection(group.medication)
                                    }
                                )
                            }
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(Color.pillrSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus Timeline")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.pillrBackground)
        }
    }
    
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundColor(Color.pillrSecondary.opacity(0.7))
            
            Text("Map your focus windows")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
            
            VStack(spacing: 10) {
                Text("When you label a medication as a stimulant, record the approximate time it starts working and how long it lasts. This allows us to define your expected focus periods.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.pillrSecondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text("Log each dose at the moment you take it so the timeline remains accurate.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.pillrSecondary.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.pillrSecondary.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.top, 16)
    }
}

private struct FocusPlannerSummaryCard: View {
    let card: FocusTimelineView.FocusPlannerCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.82))
                .tracking(0.7)

            Text(card.value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(FocusTimelineCardPalette.titleText)

            Text(card.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FocusTimelineCardPalette.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FocusTimelineCardPalette.divider.opacity(0.7), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

private struct FocusWindowRow: View {
    let group: FocusTimelineView.FocusWindowGroup
    let formatTime: (Date) -> String
    let onSelectMedication: () -> Void

    private func aiEffectsGoneTiming(for medication: Medication) -> (label: String, minMinutes: Int?, maxMinutes: Int?)? {
        if let effectsGoneMinutes = medication.effectsGoneMinutes {
            return (formatDurationLabel(minutes: effectsGoneMinutes), effectsGoneMinutes, effectsGoneMinutes)
        }

        guard medication.medicationType == .stimulant,
              let notes = medication.notes,
              !notes.isEmpty else {
            return nil
        }

        for rawLine in notes.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = "- Most effect gone around:"
            let altPrefix = "Most effect gone around:"

            if trimmed.hasPrefix(prefix) {
                let rawLabel = trimmed.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
                let range = effectsGoneRangeMinutes(from: rawLabel)
                let displayLabel = range.map { formatDurationLabel(minutes: $0.max) } ?? rawLabel
                return (displayLabel, range?.min, range?.max)
            }
            if trimmed.hasPrefix(altPrefix) {
                let rawLabel = trimmed.replacingOccurrences(of: altPrefix, with: "").trimmingCharacters(in: .whitespaces)
                let range = effectsGoneRangeMinutes(from: rawLabel)
                let displayLabel = range.map { formatDurationLabel(minutes: $0.max) } ?? rawLabel
                return (displayLabel, range?.min, range?.max)
            }
        }

        return nil
    }

    private func effectsGoneRangeMinutes(from label: String) -> (min: Int, max: Int)? {
        let normalized = label
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        let defaultUnit: String? = normalized.contains("hr") || normalized.contains("h") ? "hr" :
            (normalized.contains("min") || normalized.contains("m") ? "min" : nil)

        let parts = normalized.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstPart = parts.first else { return nil }

        let firstValue = parseDurationMinutes(part: String(firstPart), defaultUnit: defaultUnit)
        let secondValue = parts.count > 1 ? parseDurationMinutes(part: String(parts[1]), defaultUnit: defaultUnit) : nil

        if let first = firstValue, let second = secondValue {
            return (min: min(first, second), max: max(first, second))
        }

        if let first = firstValue {
            return (min: first, max: first)
        }

        return nil
    }

    private func parseDurationMinutes(part: String, defaultUnit: String?) -> Int? {
        let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let unit: String? = {
            if trimmed.contains("hr") || trimmed.contains("hour") || trimmed.contains("h") {
                return "hr"
            }
            if trimmed.contains("min") || trimmed.contains("minute") || trimmed.contains("m") {
                return "min"
            }
            return defaultUnit
        }()

        let numberString = trimmed
            .replacingOccurrences(of: "hours", with: "")
            .replacingOccurrences(of: "hour", with: "")
            .replacingOccurrences(of: "hrs", with: "")
            .replacingOccurrences(of: "hr", with: "")
            .replacingOccurrences(of: "minutes", with: "")
            .replacingOccurrences(of: "minute", with: "")
            .replacingOccurrences(of: "mins", with: "")
            .replacingOccurrences(of: "min", with: "")
            .replacingOccurrences(of: "h", with: "")
            .replacingOccurrences(of: "m", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Double(numberString) else { return nil }

        if unit == "hr" {
            return Int((value * 60).rounded())
        }
        if unit == "min" {
            return Int(value.rounded())
        }

        return nil
    }

    private func formatDurationLabel(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = Double(minutes) / 60.0
        let roundedHours = (hours * 10).rounded() / 10
        if roundedHours.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(roundedHours)) hr"
        }
        return String(format: "%.1f hr", roundedHours)
    }

    private func effectsGoneCountdownLabel(
        for window: FocusTimelineView.FocusWindow,
        now: Date
    ) -> String? {
        guard let timing = aiEffectsGoneTiming(for: window.medication),
              let maxMinutes = timing.maxMinutes else {
            return nil
        }

        let baseDoseTime: Date
        switch window.status {
        case .logged(let loggedAt):
            baseDoseTime = loggedAt
        case .skipped(let skippedAt):
            baseDoseTime = skippedAt
        case .pending:
            baseDoseTime = window.doseTime
        }

        guard let target = Calendar.current.date(byAdding: .minute, value: maxMinutes, to: baseDoseTime) else {
            return nil
        }

        let remainingMinutes = Int(target.timeIntervalSince(now) / 60)
        if remainingMinutes <= 0 {
            return "All effects likely gone"
        }

        return formatRemainingMinutes(remainingMinutes)
    }

    private func formatRemainingMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }

    private func focusStateTitle(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .skipped:
            return "Skipped"
        case .pending, .logged:
            if now < window.onsetTime {
                return "Building up"
            }
            if now <= windowEnd {
                return now <= window.fadeTime ? "In focus" : "Winding down"
            }
            return "Finished"
        }
    }

    private func focusStateSummary(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .skipped:
            return "This dose was skipped, so this timing is only a guide."
        case .pending:
            return "Log this medication to start timeline tracking."
        case .logged:
            if now < window.onsetTime {
                return "Focus support starts at \(formatTime(window.onsetTime))"
            }
            if now <= window.fadeTime {
                return "Peak focus starts wearing off at \(formatTime(window.fadeTime))"
            }
            if now <= windowEnd {
                return "This focus window is easing off until \(formatTime(windowEnd))."
            }
            return "This focus window has passed for today."
        }
    }

    private func nextMomentTitle(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .skipped:
            return "Skipped"
        case .pending, .logged:
            if now < window.onsetTime {
                return "Starts in"
            }
            if now <= window.fadeTime {
                return "Softens in"
            }
            if now <= windowEnd {
                return "Ends in"
            }
            return "Ended"
        }
    }

    private func nextMomentValue(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .skipped:
            return "No active window"
        case .pending, .logged:
            if now < window.onsetTime {
                return formatRemainingMinutes(max(0, Int(window.onsetTime.timeIntervalSince(now) / 60)))
            }
            if now <= window.fadeTime {
                return formatRemainingMinutes(max(0, Int(window.fadeTime.timeIntervalSince(now) / 60)))
            }
            if now <= windowEnd {
                return formatRemainingMinutes(max(0, Int(windowEnd.timeIntervalSince(now) / 60)))
            }
            return "Finished"
        }
    }

    private func explanationLine(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        "This estimate is based on when you actually logged the dose."
    }

    private func loggedLine(for window: FocusTimelineView.FocusWindow) -> String? {
        switch window.status {
        case .logged(let date):
            return "Logged at \(formatTime(date))"
        case .skipped(let date):
            return "Skipped at \(formatTime(date))"
        case .pending:
            return nil
        }
    }

    private func showsLargeStateTitle(for window: FocusTimelineView.FocusWindow, now: Date) -> Bool {
        switch window.status {
        case .logged:
            return now <= effectiveWindowEnd(for: window)
        case .pending:
            return false
        case .skipped:
            return true
        }
    }

    private func phaseBadgeText(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .pending:
            return "Waiting"
        case .skipped:
            return "Skipped"
        case .logged:
            if now < window.onsetTime {
                return "Building up"
            }
            if now <= window.fadeTime {
                return "In focus"
            }
            if now <= windowEnd {
                return "Easing off"
            }
            return "Finished"
        }
    }

    private func phaseBadgeStyle(for window: FocusTimelineView.FocusWindow, now: Date) -> (fill: Color, text: Color) {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .pending:
            return (Color.white.opacity(0.08), FocusTimelineCardPalette.secondaryText.opacity(0.85))
        case .skipped:
            return (Color.white.opacity(0.08), FocusTimelineCardPalette.secondaryText.opacity(0.85))
        case .logged:
            if now < window.onsetTime {
                return (Color(hex: "#A7C7E7").opacity(0.28), Color(hex: "#A7C7E7"))
            }
            if now <= window.fadeTime {
                return (Color(hex: "#F7C8A4").opacity(0.28), Color(hex: "#F7C8A4"))
            }
            if now <= windowEnd {
                return (Color(hex: "#B8E6B8").opacity(0.28), Color(hex: "#B8E6B8"))
            }
            return (Color.white.opacity(0.08), FocusTimelineCardPalette.secondaryText.opacity(0.8))
        }
    }

    private func countdownSuffix(for window: FocusTimelineView.FocusWindow, now: Date) -> String {
        let windowEnd = effectiveWindowEnd(for: window)

        switch window.status {
        case .pending:
            return now < window.onsetTime ? "until start" : ""
        case .skipped:
            return ""
        case .logged:
            if now < window.onsetTime {
                return "until start"
            }
            if now <= windowEnd {
                return "remaining"
            }
            return ""
        }
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.medication.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(FocusTimelineCardPalette.titleText)
                    
                    Text(group.medication.dosageWithUnit)
                        .font(.system(size: 12))
                        .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.96))

                    if group.windows.count == 1, let loggedLine = loggedLine(for: group.windows[0]) {
                        Text(loggedLine)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.72))
                    }
                }
                
                Spacer()
            }

            Divider()
                .background(FocusTimelineCardPalette.divider.opacity(0.5))
            
            let hasMultipleDoses = group.windows.count > 1
            ForEach(Array(group.windows.enumerated()), id: \.element.id) { index, window in
                if index > 0 {
                    Divider()
                        .background(FocusTimelineCardPalette.divider.opacity(0.45))
                        .padding(.vertical, 20)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 14) {
                        if hasMultipleDoses {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Dose \(window.doseIndex + 1)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(FocusTimelineCardPalette.titleText.opacity(0.92))

                                if let loggedLine = loggedLine(for: window) {
                                    Text(loggedLine)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.72))
                                }
                            }
                        }

                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                if showsLargeStateTitle(for: window, now: now),
                                   !phaseBadgeText(for: window, now: now).isEmpty {
                                    let badgeStyle = phaseBadgeStyle(for: window, now: now)

                                    Text(phaseBadgeText(for: window, now: now))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(badgeStyle.text)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(badgeStyle.fill)
                                        )
                                }

                                if showsLargeStateTitle(for: window, now: now) {
                                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                                        Text(nextMomentValue(for: window, now: now))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(FocusTimelineCardPalette.titleText)

                                        let suffix = countdownSuffix(for: window, now: now)
                                        if !suffix.isEmpty {
                                            Text(suffix)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.82))
                                        }
                                    }
                                }

                                if case .pending = window.status {
                                    Text(focusStateSummary(for: window, now: now))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            FocusTimelineCardPalette.secondaryTint.opacity(0.22),
                                            FocusTimelineCardPalette.secondaryTint.opacity(0.12),
                                            FocusTimelineCardPalette.secondaryTint.opacity(0.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }

                    if case .pending = window.status {
                        VStack(alignment: .leading, spacing: 14) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(FocusTimelineCardPalette.background.opacity(0.78))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FocusTimelineCardPalette.divider.opacity(0.3), lineWidth: 1)
                                )
                                .overlay(
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack {
                                            Text(formatTime(window.doseTime))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.65))
                                            Spacer()
                                            Text(formatTime(window.fadeTime))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.65))
                                        }

                                        Capsule()
                                            .fill(FocusTimelineCardPalette.secondaryTint.opacity(0.45))
                                            .frame(height: 14)

                                        HStack(alignment: .top, spacing: 12) {
                                            disabledLegendItem(title: "Building up")
                                            disabledLegendItem(title: "Active")
                                            disabledLegendItem(title: "Easing off")
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                )
                                .frame(height: 180)
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 12)
                    } else {
                        FocusBar(
                            doseTime: chartDoseTime(for: window),
                            onsetTime: window.onsetTime,
                            fadeTime: window.fadeTime,
                            wornOffTime: effectsGoneTargetDate(for: window),
                            now: now
                        )
                        .padding(.top, 2)
                        .padding(.bottom, 12)

                        Text(explanationLine(for: window, now: now))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FocusTimelineCardPalette.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FocusTimelineCardPalette.divider.opacity(0.7), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FocusTimelineCardPalette.divider.opacity(0.3), lineWidth: 0.6)
                .padding(0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onSelectMedication()
        }
    }

    private func chartDoseTime(for window: FocusTimelineView.FocusWindow) -> Date {
        switch window.status {
        case .logged(let date), .skipped(let date):
            return date
        case .pending:
            return window.doseTime
        }
    }

    private func effectsGoneTargetDate(for window: FocusTimelineView.FocusWindow) -> Date? {
        guard let timing = aiEffectsGoneTiming(for: window.medication),
              let maxMinutes = timing.maxMinutes else {
            return nil
        }

        let baseDoseTime = chartDoseTime(for: window)
        return Calendar.current.date(byAdding: .minute, value: maxMinutes, to: baseDoseTime)
    }

    private func effectiveWindowEnd(for window: FocusTimelineView.FocusWindow) -> Date {
        effectsGoneTargetDate(for: window) ?? window.fadeTime
    }

    private func disabledLegendItem(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(FocusTimelineCardPalette.secondaryText.opacity(0.18))
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            Text("Waiting to log")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FocusBar: View {
    let doseTime: Date
    let onsetTime: Date
    let fadeTime: Date
    let wornOffTime: Date?
    let now: Date

    @State private var animateNowMarker = false
    
    private let chartHeight: CGFloat = 84

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func chartWindow() -> (start: Date, end: Date) {
        let baseStart = doseTime
        let baseEnd = wornOffTime ?? fadeTime
        let visibleStart = min(baseStart, now)
        let visibleEnd = max(baseEnd, now)

        return (
            start: visibleStart,
            end: visibleEnd
        )
    }

    private func normalizedX(for date: Date, width: CGFloat, start: Date, end: Date) -> CGFloat {
        let span = max(end.timeIntervalSince(start), 1)
        let seconds = date.timeIntervalSince(start)
        let progress = min(max(seconds / span, 0), 1)
        return width * CGFloat(progress)
    }

    private func formatRange(_ start: Date, _ end: Date) -> String {
        "\(formatTime(start)) - \(formatTime(end))"
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let window = chartWindow()
            let windowStart = window.start
            let windowEnd = window.end
            let nowX = normalizedX(for: now, width: width, start: windowStart, end: windowEnd)
            let trackY: CGFloat = 34
            let buildUpColor = Color(hex: "#A7C7E7")
            let activeColor = Color(hex: "#F7C8A4")
            let easingColor = Color(hex: "#B8E6B8")

            let doseX = normalizedX(for: doseTime, width: width, start: windowStart, end: windowEnd)
            let onsetX = normalizedX(for: onsetTime, width: width, start: windowStart, end: windowEnd)
            let fadeX = normalizedX(for: fadeTime, width: width, start: windowStart, end: windowEnd)
            let wornOffX = normalizedX(for: wornOffTime ?? windowEnd, width: width, start: windowStart, end: windowEnd)
            let buildUpEndX = min(onsetX, width)
            let activeEndX = min(max(fadeX, buildUpEndX), width)
            let easingEndX = min(max(wornOffX, activeEndX), width)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(formatTime(windowStart))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.8))
                    Spacer()
                    Text(formatTime(windowEnd))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.8))
                }

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: chartHeight)

                    Capsule()
                        .fill(FocusTimelineCardPalette.secondaryTint.opacity(0.65))
                        .frame(height: 14)
                        .offset(y: trackY)

                    phaseSegment(from: doseX, to: buildUpEndX, color: buildUpColor)
                        .offset(y: trackY)

                    phaseSegment(from: buildUpEndX, to: activeEndX, color: activeColor)
                        .offset(y: trackY)

                    phaseSegment(from: activeEndX, to: easingEndX, color: easingColor)
                        .offset(y: trackY)

                    segmentLabel("Building up", from: doseX, to: buildUpEndX, width: width)
                        .offset(y: trackY + 22)

                    segmentLabel("Active", from: buildUpEndX, to: activeEndX, width: width)
                        .offset(y: trackY + 22)

                    segmentLabel("Easing off", from: activeEndX, to: easingEndX, width: width)
                        .offset(y: trackY + 22)

                    Capsule()
                        .fill(FocusTimelineCardPalette.titleText.opacity(0.98))
                        .frame(width: 5, height: 34)
                        .shadow(color: FocusTimelineCardPalette.titleText.opacity(animateNowMarker ? 0.35 : 0.12), radius: animateNowMarker ? 7 : 2)
                        .offset(x: nowX - 2.5, y: trackY - 22)

                    Text("now · \(formatTime(now))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FocusTimelineCardPalette.titleText)
                        .position(x: min(max(nowX, 54), width - 54), y: -3)
                }
                .padding(.top, 10)

                HStack(alignment: .top, spacing: 12) {
                    legendItem(
                        color: buildUpColor,
                        title: "Building up",
                        startTime: formatTime(doseTime),
                        endTime: formatTime(onsetTime)
                    )
                    legendItem(
                        color: activeColor,
                        title: "Active",
                        startTime: formatTime(onsetTime),
                        endTime: formatTime(fadeTime)
                    )
                    legendItem(
                        color: easingColor,
                        title: "Easing off",
                        startTime: formatTime(fadeTime),
                        endTime: formatTime(wornOffTime ?? fadeTime)
                    )
                }
                .padding(.top, 2)

            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(height: 208)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animateNowMarker = true
            }
        }
    }

    private func phaseSegment(from startX: CGFloat, to endX: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: max(10, endX - startX), height: 14)
            .offset(x: startX)
    }

    private func segmentLabel(_ title: String, from startX: CGFloat, to endX: CGFloat, width: CGFloat) -> some View {
        let segmentWidth = endX - startX
        let midpoint = min(max((startX + endX) / 2, 42), width - 42)

        return Group {
            if segmentWidth > 74 {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .position(x: midpoint, y: 0)
            }
        }
    }

    private func legendItem(color: Color, title: String, startTime: String, endTime: String, border: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(border ?? .clear, lineWidth: border == nil ? 0 : 1)
                    )

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FocusTimelineCardPalette.titleText.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(startTime)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.72))

                Text(endTime)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FocusTimelineCardPalette.secondaryText.opacity(0.5))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ADHDDoseTimelineSheet: View {
    let entry: ADHDDoseTimelineEntry

    @Environment(\.dismiss) private var dismiss
    private let cardCornerRadius: CGFloat = 16

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private var shiftDescription: String? {
        guard let scheduled = entry.scheduledTime else { return nil }

        let minutesShift = Int(entry.actualTime.timeIntervalSince(scheduled) / 60)
        if minutesShift == 0 {
            return "You took this right on time."
        }

        let direction = minutesShift > 0 ? "later" : "earlier"
        let absoluteMinutes = abs(minutesShift)

        if absoluteMinutes < 60 {
            return "About \(absoluteMinutes) min \(direction) than planned."
        } else {
            let hours = absoluteMinutes / 60
            let minutesRemainder = absoluteMinutes % 60
            if minutesRemainder == 0 {
                return "About \(hours) hour\(hours == 1 ? "" : "s") \(direction) than planned."
            } else {
                return "About \(hours)h \(minutesRemainder)m \(direction) than planned."
            }
        }
    }

    private var focusWindowDuration: String {
        let minutes = Int(entry.fadeTime.timeIntervalSince(entry.actualTime) / 60)
        if minutes <= 0 {
            return "—"
        }
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours) hr"
        }
        return "\(hours)h \(remainder)m"
    }

    private var effectsGoneTime: Date? {
        guard let minutes = entry.medication.effectsGoneMinutes else { return nil }
        return Calendar.current.date(byAdding: .minute, value: minutes, to: entry.actualTime)
    }

    private var medicationCategoryLabel: String {
        entry.medication.medicationType == .stimulant ? "Stimulant" : entry.medication.medicationType.displayName
    }

    private var pillInventoryDescription: String? {
        guard let count = entry.medication.pillCount, count > 0 else { return nil }
        return "\(count) tablets"
    }

    private var logSummary: String {
        if let scheduled = entry.scheduledTime {
            return "Scheduled for \(formatTime(scheduled)) · Logged at \(formatTime(entry.actualTime))"
        }
        return "Logged at \(formatTime(entry.actualTime))"
    }

    private var timingDeltaValue: String? {
        guard let scheduled = entry.scheduledTime else { return nil }
        let minutesShift = Int(entry.actualTime.timeIntervalSince(scheduled) / 60)
        if minutesShift == 0 {
            return "On time"
        }
        let direction = minutesShift > 0 ? "Late" : "Early"
        let absoluteMinutes = abs(minutesShift)
        if absoluteMinutes < 60 {
            return "\(absoluteMinutes) min \(direction)"
        }
        let hours = absoluteMinutes / 60
        let minutesRemainder = absoluteMinutes % 60
        if minutesRemainder == 0 {
            return "\(hours) hr \(direction)"
        }
        return "\(hours)h \(minutesRemainder)m \(direction)"
    }

    private var timingBadge: (text: String, color: Color, background: Color) {
        guard let scheduled = entry.scheduledTime else {
            return ("Logged", Color.pillrPrimary, Color.pillrSecondary)
        }
        let minutesShift = Int(entry.actualTime.timeIntervalSince(scheduled) / 60)
        if minutesShift == 0 {
            return ("On time", Color.pillrPrimary, Color.pillrAccent)
        }
        if minutesShift > 0 {
            return ("Logged late", Color(hex: "#4A2D22"), Color(hex: "#F2B8A0"))
        }
        return ("Logged early", Color(hex: "#243146"), Color(hex: "#B6C7E6"))
    }

    @ViewBuilder
    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.pillrSecondary.opacity(0.7))
                .tracking(0.6)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func timelineStep(icon: String, title: String, time: String) -> some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.78))
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.pillrSecondary.opacity(0.8))
                .multilineTextAlignment(.center)

            Text(time)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.pillrPrimary,
                    Color.pillrPrimary
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Focus Window")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Text(timingBadge.text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(timingBadge.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(timingBadge.background.opacity(0.9))
                            )
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.medication.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.pillrBackground)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(medicationCategoryLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.9))

                            if let inventoryDescription = pillInventoryDescription {
                                Text(inventoryDescription)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                        }

                        Text("\(entry.medication.dosage) \(entry.medication.dosageUnit)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.pillrSecondary.opacity(0.85))
                            .padding(.top, 2)

                        Text(logSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.pillrSecondary.opacity(0.8))
                    }
                    .padding(.top, 6)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }

                FocusBar(
                    doseTime: entry.actualTime,
                    onsetTime: entry.onsetTime,
                    fadeTime: entry.fadeTime,
                    wornOffTime: effectsGoneTime,
                    now: Date()
                )
                .padding(.top, 4)

                Spacer()

                Button {
                    HapticManager.shared.lightImpact()
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 28)
        }
    }
}
