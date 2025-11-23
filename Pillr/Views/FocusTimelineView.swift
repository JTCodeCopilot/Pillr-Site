import SwiftUI

struct FocusTimelineView: View {
    @EnvironmentObject var store: MedicationStore
    let isModal: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingPlanner = false
    
    struct FocusWindow: Identifiable {
        let id = UUID()
        let medication: Medication
        let doseIndex: Int
        let doseTime: Date
        let onsetTime: Date
        let fadeTime: Date
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
                        windows.append(
                            FocusWindow(
                                medication: medication,
                                doseIndex: index,
                                doseTime: base,
                                onsetTime: onset,
                                fadeTime: fade
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
                    
                    guard let onset = calendar.date(byAdding: .minute, value: onsetMinutes, to: base),
                          let fade = calendar.date(byAdding: .minute, value: durationMinutes, to: base) else { continue }
                    
                    // Only keep windows that intersect today
                    if fade > today {
                        windows.append(
                            FocusWindow(
                                medication: medication,
                                doseIndex: index,
                                doseTime: base,
                                onsetTime: onset,
                                fadeTime: fade
                            )
                        )
                    }
                }
            }
        }
        
        return windows.sorted { $0.onsetTime < $1.onsetTime }
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
            guard let firstTime = first.windows.first?.doseTime,
                  let secondTime = second.windows.first?.doseTime else {
                return first.medication.name < second.medication.name
            }
            return firstTime < secondTime
        }
    }
    
    private var hasWindows: Bool {
        !focusWindows.isEmpty
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
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
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#D7CCC8"))
                                .cornerRadius(16)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            ForEach(focusWindowGroups) { group in
                                FocusWindowRow(
                                    group: group,
                                    formatTime: formatTime
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Focus Timeline")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("Each bar shows your day from midnight to midnight. The light segment is when this dose is likely to help most, and the thin vertical line marks right now.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            
            Text("No stimulant timing set")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("Mark your ADHD medications as stimulants and add when they start working and how long they last. You'll see your focus windows here.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                .multilineTextAlignment(.center)
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
    
    private var now: Date {
        Date()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "pills.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#D7CCC8"))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.medication.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Text(group.medication.dosage)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                }
                
                Spacer()
            }

            ForEach(group.windows) { window in
                let isNowInsideWindow = now >= window.onsetTime && now <= window.fadeTime
                let isAsNeededWithoutReminder = window.medication.frequency == "As needed" && window.medication.reminderTimes.isEmpty

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dose \(window.doseIndex + 1)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                            
                            Text(formatTime(window.doseTime))
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        }

                        Spacer()

                        if isNowInsideWindow {
                            Text("Now in focus window")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#404C42"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#D7CCC8"))
                                .cornerRadius(12)
                        }
                    }

                    FocusBar(
                        onsetTime: window.onsetTime,
                        fadeTime: window.fadeTime,
                        now: now
                    )
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 3) {
                        if isAsNeededWithoutReminder {
                            Text("Logged at \(formatTime(window.doseTime))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        } else {
                            Text("Based on reminder at \(formatTime(window.doseTime))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        }
                        Text("Kicks in ~\(formatTime(window.onsetTime))")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        Text("Wears off ~\(formatTime(window.fadeTime))")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.25), lineWidth: 1)
                )
        )
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
    
    private let lengthOptions: [Int] = [30, 45, 60, 90, 120]
    
    private var hasSuggestion: Bool {
        suggestedStart != nil && suggestedEnd != nil
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
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan a focus session")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Text("Pick how long you’d like to focus. Pillr will suggest a session during one of your stimulant focus windows.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session length")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        HStack(spacing: 8) {
                            ForEach(lengthOptions, id: \.self) { minutes in
                                Button {
                                    HapticManager.shared.lightImpact()
                                    sessionLengthMinutes = minutes
                                    recomputeSuggestion()
                                } label: {
                                    Text("\(minutes) min")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(
                                            minutes == sessionLengthMinutes
                                            ? Color(hex: "#404C42")
                                            : Color(hex: "#E8E8E0")
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
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
                    
                    suggestionSection
                    
                    Spacer()
                    
                    Button {
                        scheduleSession()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.and.waveform.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Schedule session reminders")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#6FBF73"),
                                    Color(hex: "#66BB6A")
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(!hasSuggestion)
                    .opacity(hasSuggestion ? 1.0 : 0.5)
                }
                .padding(20)
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
        }
        .preferredColorScheme(.dark)
    }
    
    private var suggestionSection: some View {
        Group {
            if let start = suggestedStart, let end = suggestedEnd {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                        Text("Suggested session")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                    }
                    
                    Text("\(formatTime(start)) – \(formatTime(end)) today")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.95))
                    
                    Text("We picked a time inside one of your stimulant focus windows, starting as soon as practical.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#FFB74D"))
                        Text("No good window today")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                    }
                    
                    Text("We couldn’t find enough time inside today’s stimulant windows for a \(sessionLengthMinutes)-minute session. You can still schedule your own reminder from the Notifications settings.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
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
        
        for window in windows {
            // Start no earlier than both "now" and onset
            let candidateStart = max(now, window.onsetTime)
            let candidateEnd = candidateStart.addingTimeInterval(lengthSeconds)
            
            if candidateEnd <= window.fadeTime {
                if bestStart == nil || candidateStart < bestStart! {
                    bestStart = candidateStart
                    bestEnd = candidateEnd
                }
            }
        }
        
        suggestedStart = bestStart
        suggestedEnd = bestEnd
    }
    
    private func scheduleSession() {
        guard let start = suggestedStart else { return }
        HapticManager.shared.successNotification()
        NotificationManager.shared.scheduleFocusSession(start: start, durationMinutes: sessionLengthMinutes)
        dismiss()
    }
}
