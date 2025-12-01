import SwiftUI

struct FocusTimelineView: View {
    @EnvironmentObject var store: MedicationStore
    let isModal: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingPlanner = false
    
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
                            Button {
                                HapticManager.shared.lightImpact()
                                showingPlanner = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "target")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Plan a focus session")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#404C42"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#D7CCC8"))
                                .cornerRadius(18)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
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
                    .padding(.horizontal, horizontalInsets)
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
        .sheet(isPresented: $showingPlanner) {
            FocusSessionPlannerView(
                windows: focusWindows,
                formatTime: formatTime
            )
            .environmentObject(store)
        }
    }
    
    private var horizontalInsets: CGFloat {
        if horizontalSizeClass == .regular {
            return 32
        }
        return 20
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
                    
                    Text("These focus windows assume you take each ADHD medication at its reminder time. Log a dose to adjust the timeline if you take it earlier or later.")
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.medication.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Text(group.medication.dosage)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                }
                
                Spacer()
                
                Text("\(group.windows.count) \(group.windows.count == 1 ? "dose" : "doses")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#404C42"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#D7CCC8"))
                    .cornerRadius(12)
            }
            
            ForEach(Array(group.windows.enumerated()), id: \.element.id) { index, window in
                let isNowInsideWindow = now >= window.onsetTime && now <= window.fadeTime
                let isAsNeededWithoutReminder = window.medication.frequency == "As needed" && window.medication.reminderTimes.isEmpty
                
                if index > 0 {
                    Divider()
                        .background(Color.white.opacity(0.08))
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
                            .background(isNowInsideWindow ? Color(hex: "#D7CCC8") : Color.white.opacity(0.06))
                            .cornerRadius(14)
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
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
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
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture {
            onSelectMedication()
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
        }
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
            let barRowHeight: CGFloat = 24
            
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
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(isMidday ? 0.9 : 0.7))
                                .position(x: tickX, y: labelRowHeight / 2)
                        }
                    }
                }
                .frame(height: labelRowHeight)
                
                // Bar with ticks and "now" marker
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .frame(height: 8)
                    
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
                            .frame(width: barWidth, height: 8)
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
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 2, height: 18)
                            .offset(x: nowX - 1, y: -4)
                            .shadow(color: Color.white.opacity(0.7), radius: 2, x: 0, y: 0)
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
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(isMidday ? 0.9 : 0.7))
                                .position(x: tickX, y: labelRowHeight / 2)
                        }
                    }
                }
                .frame(height: labelRowHeight)
                
                HStack {
                    Text("am")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    Spacer()
                    Text("pm")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today's focus timeline")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Text(entry.medication.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD"))

                        Text("\(entry.medication.dosage) \(entry.medication.dosageUnit)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
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
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))

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

private struct FocusSessionPlannerView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    
    let windows: [FocusTimelineView.FocusWindow]
    let formatTime: (Date) -> String
    
    @State private var sessionLengthMinutes: Int = 60
    @State private var suggestedStart: Date? = nil
    @State private var suggestedEnd: Date? = nil
    @State private var suggestedWindow: FocusTimelineView.FocusWindow? = nil
    @State private var currentDate = Date()
    
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let lengthOptions: [Int] = [30, 45, 60, 90, 120]
    private let howItWorksPoints: [(icon: String, title: String, detail: String)] = [
        ("pills.fill", "Look at today's meds", "We build focus windows from the stimulant doses you have scheduled or already logged today."),
        ("hourglass.bottomhalf.fill", "Find the freshest window", "Sessions only start when enough time remains, and never before the current moment."),
        ("bell.badge.fill", "Remind you on time", "You'll get a reminder right as the session begins so it's easy to start.")
    ]
    
    private var hasSuggestion: Bool {
        suggestedStart != nil && suggestedEnd != nil
    }
    
    private var activeFocusSession: FocusSession? {
        guard let session = store.focusSession else { return nil }
        return session.isExpired(relativeTo: currentDate) ? nil : session
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
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if let session = activeFocusSession {
                                FocusSessionStatusCard(
                                    session: session,
                                    now: currentDate,
                                    formatTime: formatTime,
                                    onEndSession: {
                                        HapticManager.shared.warningNotification()
                                        store.cancelFocusSession()
                                    }
                                )
                            }
                            
                            introSection
                            howItWorksCard
                            sessionLengthSection
                            suggestionSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                    
                    VStack(spacing: 12) {
                        Text(hasSuggestion ? "We'll remind you right when it's time to start." : "Try a shorter session or log an earlier dose to see suggestions.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                        
                        Button {
                            scheduleSession()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bell.and.waveform.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(hasSuggestion ? "Set this reminder" : "Pick a time first")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Color(hex: "#404C42"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#D7CCC8"))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(!hasSuggestion)
                        .opacity(hasSuggestion ? 1.0 : 0.5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.25))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
        }
        .onAppear {
            recomputeSuggestion()
            store.refreshFocusSessionIfNeeded(referenceDate: Date())
        }
        .onReceive(ticker) { newDate in
            currentDate = newDate
            store.refreshFocusSessionIfNeeded(referenceDate: newDate)
        }
        .preferredColorScheme(.dark)
    }
    
    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan a focus session")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#E8E8E0"))
            Text("Tell Pillr how long you want to be heads-down. We'll slot it into the next stimulant window where you're naturally primed to focus.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
        }
    }
    
    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How this works")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0").opacity(0.9))
            ForEach(howItWorksPoints, id: \.title) { point in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: point.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#404C42"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "#D7CCC8"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        Text(point.detail)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private var sessionLengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session length")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                Spacer()
                Text("\(sessionLengthMinutes) min focus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#404C42"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "#D7CCC8")))
            }
            Text("Shorter sessions are easier to place if you're running out of stimulant time today.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(lengthOptions, id: \.self) { minutes in
                    Button {
                        HapticManager.shared.lightImpact()
                        sessionLengthMinutes = minutes
                        recomputeSuggestion()
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(minutes)")
                                .font(.system(size: 18, weight: .bold))
                            Text("min")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(
                            minutes == sessionLengthMinutes
                            ? Color(hex: "#404C42")
                            : Color(hex: "#E8E8E0")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    minutes == sessionLengthMinutes
                                    ? Color(hex: "#D7CCC8")
                                    : Color.black.opacity(0.25)
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
    
    private var suggestionSection: some View {
        Group {
            if let start = suggestedStart, let end = suggestedEnd {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#404C42"))
                            .padding(10)
                            .background(Circle().fill(Color(hex: "#D7CCC8")))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggested session")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            Text(relativeStartDescription(for: start))
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                        }
                        Spacer()
                        Text("\(sessionLengthMinutes) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#404C42"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "#D7CCC8")))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(formatTime(start)) – \(formatTime(end)) today")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#F1F1E6"))
                        if let window = suggestedWindow {
                            Text("Fits inside your \(window.medication.name) focus window (roughly \(formatTime(window.onsetTime)) – \(formatTime(window.fadeTime))).")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        } else {
                            Text("We picked a time inside one of your stimulant focus windows, starting as soon as practical.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        }
                        Text("You'll get a reminder at the start, and can check it off right from the alert.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#FFB74D"))
                        Text("No good window today")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                    }
                    Text("We couldn't find enough time inside today's stimulant windows for a \(sessionLengthMinutes)-minute session. Try a shorter duration or log an earlier dose if you took one ahead of schedule.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    Divider()
                        .background(Color.white.opacity(0.1))
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                        Text("Need a reminder anyway? Set a custom notification from Settings > Notifications.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func recomputeSuggestion() {
        let now = Date()
        let lengthSeconds = TimeInterval(sessionLengthMinutes * 60)
        
        var bestStart: Date? = nil
        var bestEnd: Date? = nil
        var matchingWindow: FocusTimelineView.FocusWindow? = nil
        
        for window in windows {
            let candidateStart = max(now, window.onsetTime)
            let candidateEnd = candidateStart.addingTimeInterval(lengthSeconds)
            
            if candidateEnd <= window.fadeTime {
                if bestStart == nil || candidateStart < bestStart! {
                    bestStart = candidateStart
                    bestEnd = candidateEnd
                    matchingWindow = window
                }
            }
        }
        
        suggestedStart = bestStart
        suggestedEnd = bestEnd
        suggestedWindow = matchingWindow
    }
    
    private func scheduleSession() {
        guard let start = suggestedStart else { return }
        HapticManager.shared.successNotification()
        store.planFocusSession(start: start, durationMinutes: sessionLengthMinutes)
        dismiss()
    }
    
    private func relativeStartDescription(for start: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: start, relativeTo: Date())
    }
}

private struct FocusSessionStatusCard: View {
    let session: FocusSession
    let now: Date
    let formatTime: (Date) -> String
    let onEndSession: () -> Void
    
    private var state: FocusSession.State {
        session.state(relativeTo: now)
    }
    
    private var statusLabel: String {
        switch state {
        case .active:
            return "In progress"
        case .upcoming:
            return "Scheduled"
        case .finished:
            return "Completed"
        }
    }
    
    private var headerIcon: String {
        state == .active ? "target" : "calendar.badge.clock"
    }
    
    private var subtitle: String {
        switch state {
        case .active:
            return "Wraps around \(formatTime(session.endDate)) (\(relativeDescription(for: session.endDate)))."
        case .upcoming:
            return "Starts \(relativeDescription(for: session.startDate)) at \(formatTime(session.startDate))."
        case .finished:
            return "This session finished just now."
        }
    }
    
    private var actionTitle: String {
        state == .active ? "End session early" : "Cancel session"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: headerIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#404C42"))
                    .padding(10)
                    .background(Color(hex: "#D7CCC8"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus session")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                }
                
                Spacer()
                
                Text(statusLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#404C42"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#D7CCC8"))
                    .clipShape(Capsule())
            }
            
            PomodoroTimerView(session: session, now: now)
            
            HStack(spacing: 16) {
                infoColumn(title: "Start", value: formatTime(session.startDate))
                infoColumn(title: "End", value: formatTime(session.endDate))
                infoColumn(title: "Length", value: "\(session.durationMinutes) min")
            }
            
            Button {
                HapticManager.shared.lightImpact()
                onEndSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: state == .active ? "stop.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#F2DEDA"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func infoColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#F1F1E6"))
        }
    }
    
    private func relativeDescription(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

private struct PomodoroTimerView: View {
    let session: FocusSession
    let now: Date
    
    private let focusInterval: TimeInterval = 25 * 60
    private let breakInterval: TimeInterval = 5 * 60
    
    private enum TimerPhase {
        case upcoming(secondsUntilStart: Int)
        case focus(remaining: Int, cycle: Int, totalCycles: Int, sessionRemaining: Int)
        case rest(remaining: Int, cycle: Int, totalCycles: Int, sessionRemaining: Int)
        case finished
    }
    
    private struct PomodoroCycleInfo {
        let isBreak: Bool
        let remainingSeconds: Int
        let cycleIndex: Int
        let totalCycles: Int
    }
    
    private var state: FocusSession.State {
        session.state(relativeTo: now)
    }
    
    private var timerPhase: TimerPhase {
        switch state {
        case .upcoming:
            return .upcoming(secondsUntilStart: session.secondsUntilStart(relativeTo: now))
        case .active:
            let totalRemaining = max(0, Int(session.endDate.timeIntervalSince(now)))
            if let info = currentCycleInfo() {
                if info.isBreak {
                    return .rest(
                        remaining: info.remainingSeconds,
                        cycle: info.cycleIndex,
                        totalCycles: info.totalCycles,
                        sessionRemaining: totalRemaining
                    )
                } else {
                    return .focus(
                        remaining: info.remainingSeconds,
                        cycle: info.cycleIndex,
                        totalCycles: info.totalCycles,
                        sessionRemaining: totalRemaining
                    )
                }
            }
            return .focus(
                remaining: totalRemaining,
                cycle: 1,
                totalCycles: totalCycleCount,
                sessionRemaining: totalRemaining
            )
        case .finished:
            return .finished
        }
    }
    
    private var totalCycleCount: Int {
        guard session.totalDurationSeconds > 0 else { return 1 }
        let cycleLength = focusInterval + breakInterval
        return max(1, Int(ceil(session.totalDurationSeconds / cycleLength)))
    }
    
    private var overallProgress: CGFloat {
        guard session.totalDurationSeconds > 0 else { return 1 }
        switch state {
        case .upcoming:
            return 0
        case .finished:
            return 1
        case .active:
            let elapsed = max(0, now.timeIntervalSince(session.startDate))
            let clampedElapsed = min(session.totalDurationSeconds, elapsed)
            return CGFloat(clampedElapsed / session.totalDurationSeconds)
        }
    }
    
    private var phaseCountdown: String {
        switch timerPhase {
        case .upcoming(let secondsUntilStart):
            return timeString(from: secondsUntilStart)
        case .focus(let remaining, _, _, _),
             .rest(let remaining, _, _, _):
            return timeString(from: remaining)
        case .finished:
            return "00:00"
        }
    }
    
    private var shortPhaseLabel: String {
        switch timerPhase {
        case .upcoming:
            return "Ready"
        case .focus:
            return "Focus"
        case .rest:
            return "Break"
        case .finished:
            return "Done"
        }
    }
    
    private var phaseDetail: String {
        switch timerPhase {
        case .upcoming(let seconds):
            return "Session begins in \(timeString(from: seconds)). Take a breath and prep your workspace."
        case .focus(_, let cycle, let totalCycles, let sessionRemaining):
            return "Cycle \(cycle) of \(totalCycles) • \(timeString(from: sessionRemaining)) left in today's session."
        case .rest(_, let cycle, let totalCycles, let sessionRemaining):
            let nextCycle = min(totalCycles, cycle + 1)
            return "Reset before cycle \(nextCycle) • \(timeString(from: sessionRemaining)) total minutes remain."
        case .finished:
            return "Nice work. Session complete."
        }
    }
    
    private var phaseAccent: Color {
        switch timerPhase {
        case .upcoming:
            return Color(hex: "#F5E6D3")
        case .focus:
            return Color(hex: "#9FD7C1")
        case .rest:
            return Color(hex: "#9FB8D7")
        case .finished:
            return Color(hex: "#C7C7BD")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pomodoro timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: overallProgress)
                        .stroke(
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .foregroundColor(phaseAccent)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: overallProgress)
                    
                    VStack(spacing: 4) {
                        Text(phaseCountdown)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#F1F1E6"))
                        Text(shortPhaseLabel.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
                .frame(width: 130, height: 130)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(phaseDetail)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Each cycle = 25 min focus, 5 min reset.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func currentCycleInfo() -> PomodoroCycleInfo? {
        guard session.totalDurationSeconds > 0 else { return nil }
        let elapsed = now.timeIntervalSince(session.startDate)
        guard elapsed >= 0 else { return nil }
        
        let clampedElapsed = min(session.totalDurationSeconds, elapsed)
        let cycleLength = focusInterval + breakInterval
        let totalCycles = totalCycleCount
        let sessionRemaining = max(0, session.endDate.timeIntervalSince(now))
        
        let cycleIndex = min(totalCycles - 1, Int(clampedElapsed / cycleLength))
        let progressWithinCycle = clampedElapsed.truncatingRemainder(dividingBy: cycleLength)
        
        if progressWithinCycle < focusInterval {
            let remaining = min(focusInterval - progressWithinCycle, sessionRemaining)
            return PomodoroCycleInfo(
                isBreak: false,
                remainingSeconds: Int(max(0, remaining)),
                cycleIndex: cycleIndex + 1,
                totalCycles: totalCycles
            )
        } else {
            let remaining = min(cycleLength - progressWithinCycle, sessionRemaining)
            return PomodoroCycleInfo(
                isBreak: true,
                remainingSeconds: Int(max(0, remaining)),
                cycleIndex: min(totalCycles, cycleIndex + 1),
                totalCycles: totalCycles
            )
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let remainder = clamped % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
