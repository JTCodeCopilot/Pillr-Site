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
                                status: status
                            )
                        )
                    }
                }
            } else {
                // For scheduled ADHD medications, derive windows from their reminder times.
                let times = medication.reminderTimes.isEmpty ? [medication.timeToTake] : medication.reminderTimes
                
                for (index, rawTime) in times.enumerated() {
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: rawTime)
                    guard let base = calendar.date(
                        bySettingHour: timeComponents.hour ?? 8,
                        minute: timeComponents.minute ?? 0,
                        second: 0,
                        of: today
                    ) else { continue }
                    
                    let adjustedBase = actualDoseTime(
                        for: medication,
                        scheduledIndex: medication.reminderTimes.isEmpty ? nil : index,
                        scheduledBase: base,
                        todaysLogs: todaysLogs
                    )
                    let status = doseStatus(
                        for: medication,
                        scheduledIndex: medication.reminderTimes.isEmpty ? nil : index,
                        todaysLogs: allLogs
                    )
                    
                    guard let adjustedOnset = calendar.date(byAdding: .minute, value: onsetMinutes, to: adjustedBase),
                          let adjustedFade = calendar.date(byAdding: .minute, value: durationMinutes, to: adjustedBase) else { continue }
                    
                    // Only keep windows that intersect today
                    if adjustedFade > today {
                        windows.append(
                            FocusWindow(
                                medication: medication,
                                doseIndex: index,
                                doseTime: adjustedBase,
                                onsetTime: adjustedOnset,
                                fadeTime: adjustedFade,
                                status: status
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
            !log.skipped && calendar.isDate(log.takenAt, inSameDayAs: today)
        }
        
        return Dictionary(grouping: todaysLogs, by: { $0.medicationID })
    }
    
    private var todaysAllLogsByMedication: [UUID: [MedicationLog]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todaysLogs = store.logs.filter { log in
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
        
        return "Ends around \(formatTime(nextWindow.fadeTime))"
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
    
    private func actualDoseTime(
        for medication: Medication,
        scheduledIndex: Int?,
        scheduledBase: Date,
        todaysLogs: [UUID: [MedicationLog]]
    ) -> Date {
        guard let logs = todaysLogs[medication.id], !logs.isEmpty else {
            return scheduledBase
        }
        
        if let index = scheduledIndex,
           let matchingLog = logs.first(where: { $0.reminderIndex == index }) {
            return matchingLog.takenAt
        }
        
        if scheduledIndex == nil,
           let singleLog = logs.first(where: { $0.reminderIndex == nil }) {
            return singleLog.takenAt
        }
        
        return scheduledBase
    }
    
    private func doseStatus(
        for medication: Medication,
        scheduledIndex: Int?,
        todaysLogs: [UUID: [MedicationLog]]
    ) -> DoseStatus {
        guard let logs = todaysLogs[medication.id] else {
            return .pending
        }
        
        if let index = scheduledIndex,
           let matchingLog = logs.first(where: { $0.reminderIndex == index }) {
            return matchingLog.skipped ? .skipped(matchingLog.takenAt) : .logged(matchingLog.takenAt)
        }
        
        if scheduledIndex == nil,
           let singleLog = logs.first(where: { $0.reminderIndex == nil }) {
            return singleLog.skipped ? .skipped(singleLog.takenAt) : .logged(singleLog.takenAt)
        }
        
        return .pending
    }
    
    init(isModal: Bool = true) {
        self.isModal = isModal
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#404C42"),
                        Color(hex: "#3A443D")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        
                        if hasWindows {
                            ForEach(focusWindowGroups) { group in
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
        .preferredColorScheme(.dark)
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
    
    private var now: Date { Date() }
    
    var body: some View {
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
            
            ForEach(Array(group.windows.enumerated()), id: \.element.id) { index, window in
                let isNowInsideWindow = now >= window.onsetTime && now <= window.fadeTime
                let isAsNeededWithoutReminder = window.medication.frequency == "As needed" && window.medication.reminderTimes.isEmpty
                
                if index > 0 {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.vertical, 20)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dose \(window.doseIndex + 1)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            let statusInfo = statusSubtitle(for: window, isAsNeededWithoutReminder: isAsNeededWithoutReminder)
                            Text(statusInfo.text)
                                .font(.system(size: 12))
                                .foregroundColor(statusInfo.color)
                        }
                        
                        Spacer()
                        
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
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                .tracking(0.6)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(timeComponent)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "#F8F8F1"))
                
                if !meridiemComponent.isEmpty {
                    Text(meridiemComponent)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0").opacity(0.8))
                        .padding(.leading, 2)
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
    private let hourLabelOpacity: Double = 0.7
    private let trackCornerRadius: CGFloat = 12
    private let trackFillOpacity: Double = 0.2
    private let handleWidth: CGFloat = 14
    private let handleHeight: CGFloat = 26
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
            
            let labelRowHeight: CGFloat = 16
            let barRowHeight: CGFloat = 25
            
            VStack(alignment: .leading, spacing: 4) {
                // PM hours above the bar
                ZStack(alignment: .topLeading) {
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickX = width * (tick / totalMinutes)
                        let isMidday = Int(tick) == 12 * 60
                        let isLeftMidnight = Int(tick) == 0
                        let isRightMidnight = Int(tick) == Int(totalMinutes)
                        
                        if isPM(tick) || isRightMidnight {
                            Text(label(for: tick))
                                .font(.system(size: 9, weight: isMidday ? .semibold : .regular))
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
                    .frame(height: 9)
                    
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
                            .frame(width: barWidth, height: 9)
                            .offset(x: barStart)
                    }
                    
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickX = width * (tick / totalMinutes)
                        let isMidday = Int(tick) == 12 * 60
                        
                        Rectangle()
                            .fill(Color.white.opacity(isMidday ? 0.35 : 0.18))
                            .frame(width: 1, height: isMidday ? 10 : 6)
                            .offset(x: tickX - 0.5, y: 10)
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
                
                // AM hours below the bar
                ZStack(alignment: .topLeading) {
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickX = width * (tick / totalMinutes)
                        let isMidday = Int(tick) == 12 * 60
                        let isLeftMidnight = Int(tick) == 0
                        let isRightMidnight = Int(tick) == Int(totalMinutes)
                        
                        if !isPM(tick) || isLeftMidnight {
                            Text(label(for: tick))
                                .font(.system(size: 9, weight: isMidday ? .semibold : .regular))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(hourLabelOpacity))
                                .position(x: tickX, y: labelRowHeight / 2)
                        }
                    }
                }
                .frame(height: labelRowHeight)
                
                HStack {
                    Text("am")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                        .baselineOffset(2)
                    Spacer()
                    Text("pm")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                        .baselineOffset(2)
                }
            }
        }
        .frame(height: 64)
    }
}

struct ADHDDoseTimelineSheet: View {
    let entry: ADHDDoseTimelineEntry

    @Environment(\.dismiss) private var dismiss

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

    private var effectWindowDescription: String {
        let start = formatTime(entry.onsetTime)
        let end = formatTime(entry.fadeTime)
        return "Expected focus window ~\(start) to ~\(end)."
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#404C42"),
                    Color(hex: "#3A443D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: "#D7CCC8"))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's focus timeline")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Text(entry.medication.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD"))

                        Text("\(entry.medication.dosage) \(entry.medication.dosageUnit)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            .padding(.top, 4)
                    }
                }

                FocusBar(
                    onsetTime: entry.onsetTime,
                    fadeTime: entry.fadeTime,
                    now: Date()
                )
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    if let scheduled = entry.scheduledTime {
                        Text("Scheduled for \(formatTime(scheduled)), logged at \(formatTime(entry.actualTime)).")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    } else {
                        Text("Logged at \(formatTime(entry.actualTime)).")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    }

                    Text(effectWindowDescription)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.top, 8)

                    if let shift = shiftDescription {
                        Text(shift)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    }
                }
                .padding(.top, 4)

                Spacer()

                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#404C42"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "#D7CCC8"))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 16)
        }
    }
}
