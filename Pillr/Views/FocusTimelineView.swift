import SwiftUI

struct FocusTimelineView: View {
    @EnvironmentObject var store: MedicationStore
    let isModal: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
            let sortedGroup = group.sorted { $0.doseTime < $1.doseTime }
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
                LinearGradient.pillrBackground
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
                    .padding(.horizontal, timelineHorizontalPadding)
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
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
            }
        }
    }
    
    private var horizontalInsets: CGFloat {
        if horizontalSizeClass == .regular {
            return 32
        }
        return 20
    }

    private var timelineHorizontalPadding: CGFloat {
        horizontalInsets + 12
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Focus Timeline")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#E8E8E0"))
            }
            
            if hasWindows {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    
                    Text("These focus windows assume you take each ADHD medication at the scheduled reminder time. If you take a dose earlier or later, log it so the timeline can update accordingly.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            
            Text("Map your focus windows")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            VStack(spacing: 10) {
                Text("When you label a medication as a stimulant, record the approximate time it starts working and how long it lasts. This allows us to define your expected focus periods.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text("Log each dose at the moment you take it so the timeline remains accurate.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
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
                        .stroke(Color(hex: "#C7C7BD").opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.top, 16)
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
    
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.medication.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Text(group.medication.dosage)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(1.0))
                }
                
                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.10))
            
            let hasMultipleDoses = group.windows.count > 1
            ForEach(Array(group.windows.enumerated()), id: \.element.id) { index, window in
                let isNowInsideWindow = now >= window.onsetTime && now <= window.fadeTime
                let isAsNeededWithoutReminder = window.medication.frequency == "As needed" && window.medication.reminderTimes.isEmpty
                let effectsGoneTiming = aiEffectsGoneTiming(for: window.medication)
                
                if index > 0 {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.vertical, 20)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    let loggedTime: Date? = {
                        if case .logged(let date) = window.status { return date }
                        return nil
                    }()
                    let isLogged = loggedTime != nil
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if hasMultipleDoses {
                                Text("Dose \(window.doseIndex + 1)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                            }

                            if let loggedTime {
                                Text("Logged \(formatTime(loggedTime))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.14))
                                    .cornerRadius(12)
                            } else {
                                let statusInfo = statusSubtitle(for: window, isAsNeededWithoutReminder: isAsNeededWithoutReminder)
                                Text(statusInfo.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(statusInfo.color)
                            }
                        }
                        
                        Spacer()
                        
                        if !isLogged || isNowInsideWindow {
                            let badgeText = isNowInsideWindow ? "Now" : formatTime(window.onsetTime)
                            Text(badgeText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isNowInsideWindow ? Color(hex: "#404C42") : Color(hex: "#C7C7BD"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isNowInsideWindow ? Color(hex: "#D7CCC8") : Color.white.opacity(0.14))
                                .cornerRadius(12)
                                .frame(minWidth: 72, alignment: .trailing)
                        }
                    }
                    
                    FocusBar(
                        onsetTime: window.onsetTime,
                        fadeTime: window.fadeTime,
                        now: now
                    )
                    .padding(.bottom, 4)
                    
                    HStack(spacing: 14) {
                        infoRow(title: "Kicks in", value: formatTime(window.onsetTime))
                        infoRow(title: "Fades", value: formatTime(window.fadeTime))
                    }
                    .padding(.top, 6)

                    if let effectsGoneTiming {
                        let countdownLabel = effectsGoneCountdownLabel(for: window, now: now)
                        let displayValue = countdownLabel ?? effectsGoneTiming.label
                        HStack {
                            infoRow(title: "Most effects gone", value: displayValue)
                        }
                        .padding(.top, 6)
                    }

                    if let scheduledReminder = window.scheduledDoseTime {
                        Text("Based on the \(formatTime(scheduledReminder)) reminder")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.65))
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 26))
        .onTapGesture {
            onSelectMedication()
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        let parts = value.split(separator: " ")
        let timeComponent = parts.first.map(String.init) ?? value
        let meridiemComponent = parts.count > 1 ? String(parts.last!).lowercased() : ""
        let isMeridiem = meridiemComponent == "am" || meridiemComponent == "pm"
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                .tracking(0.6)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                if isMeridiem {
                    Text(timeComponent)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#F8F8F1"))
                    
                    Text(meridiemComponent)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0").opacity(0.8))
                        .padding(.leading, 2)
                } else {
                    Text(value)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#F8F8F1"))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
    }
    
    private func statusSubtitle(
        for window: FocusTimelineView.FocusWindow,
        isAsNeededWithoutReminder: Bool
    ) -> (text: String, color: Color) {
        switch window.status {
        case .logged(let date):
            return ("Logged at \(formatTime(date))", Color(hex: "#9FD7C1"))
        case .skipped(let date):
            return ("Skipped at \(formatTime(date))", Color(hex: "#F2B8A0"))
        case .pending:
            let prefix = isAsNeededWithoutReminder ? "Logged at" : "Reminder at"
            return ("\(prefix) \(formatTime(window.doseTime))", Color(hex: "#C7C7BD").opacity(0.9))
        }
    }
}

private struct FocusBar: View {
    let onsetTime: Date
    let fadeTime: Date
    let now: Date
    
    private let totalMinutes: CGFloat = 24 * 60
    private let hourTicks: [CGFloat] = stride(from: 0, through: 24, by: 2).map { CGFloat($0 * 60) }
    private let labelRowHeight: CGFloat = 18
    private let barRowHeight: CGFloat = 18
    private let hourLabelOpacity: Double = 0.65
    private let trackCornerRadius: CGFloat = 12
    private let trackFillOpacity: Double = 0.14
    private let handleWidth: CGFloat = 6
    private let handleHeight: CGFloat = 30
    private let handleShadowRadius: CGFloat = 4
    
    private func minutesSinceMidnight(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hours = CGFloat(components.hour ?? 0)
        let minutes = CGFloat(components.minute ?? 0)
        return hours * 60 + minutes
    }
    
    private func label(for minutes: CGFloat) -> String {
        let clamped = max(0, min(Int(minutes), Int(totalMinutes)))
        let hours = (clamped / 60) % 24
        let hour12 = hours % 12
        let displayHour = hour12 == 0 ? 12 : hour12
        return "\(displayHour)"
    }
    
    private func isPM(_ minutes: CGFloat) -> Bool {
        let clamped = max(0, min(Int(minutes), Int(totalMinutes)))
        // Treat the end-of-day (24:00) as PM so the
        // right-edge "12" only appears on the PM row.
        if clamped == Int(totalMinutes) {
            return true
        }
        let hours = (clamped / 60) % 24
        return hours >= 12
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let onsetMinutes = minutesSinceMidnight(onsetTime)
            let fadeMinutes = minutesSinceMidnight(fadeTime)
            let nowMinutes = minutesSinceMidnight(now)
            let calendar = Calendar.current

            // Determine if this window crosses midnight into the next day.
            let crossesMidnight = !calendar.isDate(onsetTime, inSameDayAs: fadeTime)
            
            let clampedOnset = max(0, min(totalMinutes, onsetMinutes))
            let clampedFadeRaw = max(0, min(totalMinutes, fadeMinutes))
            
            // Compute one or two bar segments depending on whether the window
            // crosses midnight. When it does, we render:
            //   - from onset -> midnight on the right side
            //   - from midnight -> fade on the left side
            let segments: [(start: CGFloat, end: CGFloat)] = {
                if crossesMidnight {
                    return [
                        (start: clampedOnset, end: totalMinutes),
                        (start: 0, end: clampedFadeRaw)
                    ]
                } else {
                    let clampedFade = max(clampedOnset, clampedFadeRaw)
                    return [(start: clampedOnset, end: clampedFade)]
                }
            }()
            
            let nowX = width * (max(0, min(totalMinutes, nowMinutes)) / totalMinutes)
            let showNowMarker = nowMinutes >= 0 && nowMinutes <= totalMinutes
            
            
            VStack(alignment: .leading, spacing: 8) {
                // PM hours above the bar
                ZStack(alignment: .topLeading) {
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickX = width * (tick / totalMinutes)
                        let isMidday = Int(tick) == 12 * 60
                        let isLeftMidnight = Int(tick) == 0
                        let isRightMidnight = Int(tick) == Int(totalMinutes)
                        
                        if isPM(tick) || isRightMidnight {
                            Text(label(for: tick))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(hourLabelOpacity))
                                .position(x: tickX, y: labelRowHeight / 2)
                        }
                    }
                }
                .frame(height: labelRowHeight)
                
                // Bar with ticks and "now" marker
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                        .fill(Color.black.opacity(trackFillOpacity))
                        .frame(height: 7)
                   
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        let barStart = width * (segment.start / totalMinutes)
                        let barWidth = max(4, width * ((segment.end - segment.start) / totalMinutes))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#C7C7BD"),
                                        Color(hex: "#D7CCC8")
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: barWidth, height: 7)
                            .offset(x: barStart)
                    }
                    
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickX = width * (tick / totalMinutes)
                        let isMidday = Int(tick) == 12 * 60
                        let tickHeight: CGFloat = isMidday ? 12 : 8

                        Rectangle()
                            .fill(Color.white.opacity(isMidday ? 0.35 : 0.18))
                            .frame(width: 1, height: tickHeight)
                            .offset(x: tickX - 0.5, y: (barRowHeight / 2) - (tickHeight / 2))
                    }
                    
                    if showNowMarker {
                        Capsule()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: handleWidth, height: handleHeight)
                            .offset(
                                x: nowX - handleWidth / 2,
                                y: -((handleHeight - barRowHeight) / 2)
                            )
                    }
                }
                .frame(height: barRowHeight)
                .padding(.vertical, 6)
                
                // AM hours below the bar
                ZStack(alignment: .topLeading) {
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickX = width * (tick / totalMinutes)
                        let isMidday = Int(tick) == 12 * 60
                        let isLeftMidnight = Int(tick) == 0
                        let isRightMidnight = Int(tick) == Int(totalMinutes)
                        
                        if !isPM(tick) || isLeftMidnight {
                            Text(label(for: tick))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(hourLabelOpacity))
                                .position(x: tickX, y: labelRowHeight / 2)
                        }
                    }
                }
                .frame(height: labelRowHeight)
                
                HStack {
                    Text("am")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.52))
                    Spacer()
                    Text("pm")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.52))
                }
            }
        }
        .frame(height: 90)
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
        let minutes = Int(entry.fadeTime.timeIntervalSince(entry.onsetTime) / 60)
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
            return ("Logged", Color(hex: "#2F352F"), Color(hex: "#D7CCC8"))
        }
        let minutesShift = Int(entry.actualTime.timeIntervalSince(scheduled) / 60)
        if minutesShift == 0 {
            return ("On time", Color(hex: "#1F3C32"), Color(hex: "#9FD7C1"))
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
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                .tracking(0.6)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#F5F7F4"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ZStack {
            LinearGradient.pillrBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Focus Timeline")
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
                            .foregroundColor(Color(hex: "#F5F7F4"))

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
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                            .padding(.top, 2)

                        Text(logSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }
                    .padding(.top, 6)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }

                FocusBar(
                    onsetTime: entry.onsetTime,
                    fadeTime: entry.fadeTime,
                    now: Date()
                )
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Timing recap")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))

                    HStack(spacing: 14) {
                        if let scheduled = entry.scheduledTime {
                            statBlock(title: "Scheduled", value: formatTime(scheduled))
                        }
                        statBlock(title: "Logged", value: formatTime(entry.actualTime))
                        if let delta = timingDeltaValue {
                            statBlock(title: "Delta", value: delta)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: cardCornerRadius)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text("Focus window estimate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))

                    HStack(spacing: 14) {
                        statBlock(title: "Starts", value: formatTime(entry.onsetTime))
                        statBlock(title: "Fades", value: formatTime(entry.fadeTime))
                        statBlock(title: "Duration", value: focusWindowDuration)
                    }

                    if let shift = shiftDescription {
                        Text(shift)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: cardCornerRadius)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

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
