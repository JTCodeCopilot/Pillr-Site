import SwiftUI
import UIKit

struct MedicationHistoryView: View {
    @EnvironmentObject var store: MedicationStore
    let isModal: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMedication: String = "All"
    @State private var includeSkipped = true
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var selectedStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var selectedEndDate: Date = Date()
    @State private var showingDateRangePopover = false
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let compactDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let rangeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }()
    
    private let presetDays = [7, 14, 21, 30]
    private let presetColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    init(isModal: Bool = false) {
        self.isModal = isModal
    }
    
    private var medicationFilters: [String] {
        let names = Set(store.logs.map { $0.medicationName })
        return ["All"] + names.sorted()
    }
    
    private var filteredLogs: [MedicationLog] {
        let start = min(selectedStartDate, selectedEndDate)
        let end = max(selectedStartDate, selectedEndDate)
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: start)
        let rangeEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? calendar.startOfDay(for: end).addingTimeInterval(86399)

        return store.logs.filter { log in
            let matchesMedication = selectedMedication == "All" || log.medicationName == selectedMedication
            let matchesSkipFilter = includeSkipped || !log.skipped
            let inRange = log.takenAt >= rangeStart && log.takenAt <= rangeEnd
            return matchesMedication && matchesSkipFilter && inRange
        }
        .sorted { $0.takenAt > $1.takenAt }
    }
    
    private var groupedLogs: [(date: Date, logs: [MedicationLog])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredLogs) { calendar.startOfDay(for: $0.takenAt) }
        
        return groups.keys.sorted(by: >).map { date in
            let logsForDay = groups[date]?.sorted(by: { $0.takenAt > $1.takenAt }) ?? []
            return (date, logsForDay)
        }
    }
    
    private var rangeTakenCount: Int {
        filteredLogs.filter { !$0.skipped }.count
    }
    
    private var rangeAdherenceRate: String {
        let total = filteredLogs.count
        guard total > 0 else { return "—" }
        let rate = Int((Double(rangeTakenCount) / Double(total)) * 100)
        return "\(rate)%"
    }
    
    private var rangeDaysDisplayed: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: min(selectedStartDate, selectedEndDate))
        let end = calendar.startOfDay(for: max(selectedStartDate, selectedEndDate))
        let components = calendar.dateComponents([.day], from: start, to: end)
        return (components.day ?? 0) + 1
    }

    private var rangeNotesCount: Int {
        filteredLogs.filter { ($0.notes?.isEmpty == false) }.count
    }

    private var dateRangeLabel: String {
        let start = min(selectedStartDate, selectedEndDate)
        let end = max(selectedStartDate, selectedEndDate)
        let formatter = MedicationHistoryView.dayFormatter
        return "From \(formatter.string(from: start)) to \(formatter.string(from: end))"
    }

    private var compactDateRangeLabel: String {
        let start = min(selectedStartDate, selectedEndDate)
        let end = max(selectedStartDate, selectedEndDate)
        let formatter = MedicationHistoryView.compactDayFormatter
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private var dateRangeSummaryText: String {
        rangeDaysDisplayed == 1 ? "Single day selected" : "\(rangeDaysDisplayed) days selected"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#424C43")
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        statsSection
                        
                        if groupedLogs.isEmpty {
                            HistoryEmptyState()
                        } else {
                            timelineSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                }
                if isModal {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarIncludeSkippedControl
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            exportHistoryAsCSV()
                        } label: {
                            Label("Export CSV", systemImage: "doc.text")
                        }
                        
                        Button {
                            exportHistoryAsPDF()
                        } label: {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    .disabled(filteredLogs.isEmpty)
                    .accessibilityLabel("Export history")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .onChange(of: selectedStartDate) { newValue in
            if selectedEndDate < newValue {
                selectedEndDate = newValue
            }
        }
        .onChange(of: selectedEndDate) { newValue in
            if newValue < selectedStartDate {
                selectedStartDate = newValue
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("History")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("Logged doses: \(rangeTakenCount)  •  Adherence: \(rangeAdherenceRate)")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.65))
        }
        .padding(.top, 16)
    }
    
    private var dateRangeFullScreen: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#3D463F"),
                        Color(hex: "#2E352F")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    dateRangePopoverContent
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    Spacer(minLength: 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showingDateRangePopover = false
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var dateRangePopoverContent: some View {
        GlassContainer(spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a date range")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                }

                VStack(spacing: 12) {
                    dateSelectionCard(
                        label: "From",
                        selectionText: MedicationHistoryView.rangeDateFormatter.string(from: selectedStartDate)
                    ) {
                        DatePicker("", selection: $selectedStartDate, in: ...selectedEndDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .tint(Color(hex: "#E8E8E0"))
                            .scaleEffect(y: 0.8, anchor: .center)
                            .frame(height: 120)
                    }

                    dateSelectionCard(
                        label: "To",
                        selectionText: MedicationHistoryView.rangeDateFormatter.string(from: selectedEndDate)
                    ) {
                        DatePicker("", selection: $selectedEndDate, in: selectedStartDate...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .tint(Color(hex: "#E8E8E0"))
                            .scaleEffect(y: 0.8, anchor: .center)
                            .frame(height: 120)
                    }
                }

                HStack(spacing: 10) {
                    Label("\(rangeDaysDisplayed) days selected", systemImage: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    Spacer()
                    Text("\(rangeTakenCount) logged • \(rangeNotesCount) notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
                .padding(.horizontal, 6)

                Divider()
                    .overlay(Color.white.opacity(0.12))

                quickRangeMenu

                Spacer(minLength: 4)

                Button {
                    showingDateRangePopover = false
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 320, maxWidth: 420)
    }

    @ViewBuilder
    private func dateSelectionCard<Picker: View>(
        label: String,
        selectionText: String,
        @ViewBuilder picker: () -> Picker
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                Text(selectionText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
            }
            .padding(.horizontal, 4)

            picker()
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    private var quickRangeMenu: some View {
        Menu {
            ForEach(presetDays, id: \.self) { days in
                Button {
                    applyPreset(days: days)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last \(days) days")
                                .font(.system(size: 14, weight: .semibold))
                            Text(presetSubtitle(for: days))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if presetIsActive(days) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick ranges")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    Text("Jump to a recent window")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(activePresetLabel ?? "Custom")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#7FE3FF"))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var activePresetLabel: String? {
        guard Calendar.current.isDateInToday(selectedEndDate) else { return nil }
        if let match = presetDays.first(where: { presetIsActive($0) }) {
            return "Last \(match) days"
        }
        return nil
    }

    private func presetIsActive(_ days: Int) -> Bool {
        guard Calendar.current.isDateInToday(selectedEndDate) else { return false }
        return rangeDaysDisplayed == days
    }

    private func presetSubtitle(for days: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return ""
        }
        return "\(MedicationHistoryView.rangeDateFormatter.string(from: start)) – \(MedicationHistoryView.rangeDateFormatter.string(from: today))"
    }

    @ViewBuilder
    private var toolbarIncludeSkippedControl: some View {
        Menu {
            Button(includeSkipped ? "Hide skipped medication" : "Show skipped medication") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    includeSkipped.toggle()
                }
            }
        } label: {
            Image(systemName: includeSkipped ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(includeSkipped ? Color(hex: "#C7C7BD") : Color.white.opacity(0.7))
                .accessibilityLabel(includeSkipped ? "Exclude skipped doses" : "Include skipped doses")
        }
    }
    
    private var statsSection: some View {
        GlassContainer(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Refine history")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        filterControl
                        dateRangeControl
                    }

                    VStack(spacing: 14) {
                        filterControl
                        dateRangeControl
                    }
                }
            }
        }
        .padding(.top, 16)
    }

    private var filterControl: some View {
        Menu {
            ForEach(medicationFilters, id: \.self) { name in
                Button {
                    selectedMedication = name
                } label: {
                    Label(name, systemImage: name == selectedMedication ? "checkmark" : "pills")
                }
            }
        } label: {
            HistoryControlButton(
                icon: "slider.horizontal.3",
                title: "Filter",
                value: selectedMedication,
                detail: selectedMedication == "All" ? "All medications" : "Only \(selectedMedication)"
            )
        }
        .buttonStyle(.plain)
    }

    private var dateRangeControl: some View {
        Button {
            showingDateRangePopover = true
        } label: {
            HistoryControlButton(
                icon: "calendar",
                title: "Date range",
                value: compactDateRangeLabel,
                detail: dateRangeSummaryText
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingDateRangePopover) {
            dateRangeFullScreen
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedLogs, id: \.date) { date, logs in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        let isToday = Calendar.current.isDateInToday(date)

                        Text(dayLabel(for: date))
                            .font(.system(size: isToday ? 13 : 18, weight: isToday ? .semibold : .bold))
                            .foregroundColor(
                                isToday
                                    ? Color(hex: "#C7C7BD").opacity(0.55)
                                    : Color(hex: "#E8E8E0")
                            )
                    }
                    
                    VStack(spacing: 18) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                        MedicationTimelineRow(
                            log: log,
                            iconName: log.recordedIconName,
                            dosageText: log.recordedDosageWithUnit.isEmpty ? nil : log.recordedDosageWithUnit,
                            showDoseChip: log.recordedHasMultipleReminders,
                            timeText: MedicationHistoryView.timeFormatter.string(from: log.takenAt),
                            isLast: index == logs.count - 1
                        )
                        }
                    }
                }
            }
        }
        .padding(.top, 28)
    }
    
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return MedicationHistoryView.dayFormatter.string(from: date)
        }
    }
    
    private func applyPreset(days: Int) {
        let now = Date()
        selectedEndDate = now
        guard days > 1 else {
            selectedStartDate = now
            return
        }
        if let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: now) {
            selectedStartDate = start
        } else {
            selectedStartDate = now
        }
        showingDateRangePopover = false
    }
}

private struct MedicationTimelineRow: View {
    let log: MedicationLog
    let iconName: String
    let dosageText: String?
    let showDoseChip: Bool
    let timeText: String
    let isLast: Bool

    private var resolvedIconName: String {
        iconName.isEmpty ? "pill" : iconName
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color.white.opacity(log.skipped ? 0.3 : 0.45))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                Rectangle()
                    .fill(Color.white.opacity(0.035))
                    .frame(width: 0.6)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .alignmentGuide(VerticalAlignment.center) { $0[VerticalAlignment.center] }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 8) {
                        Image(systemName: resolvedIconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#D7CCC8"))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(log.medicationName)
                                .font(.body.weight(.semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            if let dosageText {
                                Text(dosageText)
                                    .font(.body.weight(.regular))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.65))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(timeText)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.015))
                        .cornerRadius(10)
                        .frame(minWidth: 66, alignment: .trailing)
                }
                
                HStack(spacing: 3) {
                    HistoryChip(
                        icon: log.skipped ? "xmark.circle.fill" : "checkmark.circle.fill",
                        text: log.skipped ? "Skipped" : "Taken",
                        tint: log.skipped ? Color(hex: "#D78B7E") : Color(hex: "#C7C7BD")
                    )
                    
                    if let pills = log.pillsConsumed {
                        HistoryChip(
                            icon: "capsule.fill",
                            text: pills == 1 ? "1 pill" : "\(pills) pills",
                            tint: Color(hex: "#C7C7BD").opacity(0.9)
                        )
                    }
                    
                    if let reminder = log.reminderIndex,
                       showDoseChip {
                        HistoryChip(
                            icon: "bell.badge.fill",
                            text: "Dose \(reminder + 1)",
                            tint: Color(hex: "#C7C7BD").opacity(0.9)
                        )
                    }
                }
                
                if let feeling = log.feelingRating {
                    HistoryChip(
                        icon: "heart.fill",
                        text: "Feeling \(feeling)/5",
                        tint: Color(hex: "#D7CCC8").opacity(0.95)
                    )
                }

                if let focus = log.focusRating {
                    HistoryChip(
                        icon: "hourglass",
                        text: "Focus \(focus)/5",
                        tint: Color(hex: "#D7CCC8")
                    )
                }
                
                if let sideEffects = log.sideEffectSeverity {
                    HistoryChip(
                        icon: "waveform.path.ecg",
                        text: "Side effects \(sideEffects)/5",
                        tint: Color(hex: "#D7CCC8").opacity(0.9)
                    )
                }
                
                if let notes = log.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
        }
    }
}

private struct HistoryChip: View {
    let icon: String
    let text: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.weight(.medium))
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(Color(hex: "#404C42"))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 28)
        .background(tint.opacity(0.9))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Export Helpers

extension MedicationHistoryView {
    private func exportHistoryAsCSV() {
        guard let url = createCSVFile() else { return }
        shareItems = [url]
        showingShareSheet = true
    }
    
    private func exportHistoryAsPDF() {
        guard let url = createPDFFile() else { return }
        shareItems = [url]
        showingShareSheet = true
    }
    
    private func createCSVFile() -> URL? {
        let logs = filteredLogs
        guard !logs.isEmpty else { return nil }
        
        var csv = "Date,Time,Medication,Dosage,Status,Notes\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for log in logs {
            let dosage = log.recordedDosageWithUnit
            let cleanNotes = (log.notes ?? "").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ",", with: ";")
            let status = log.skipped ? "Skipped" : "Taken"
            csv += "\(dateFormatter.string(from: log.takenAt)),\(timeFormatter.string(from: log.takenAt)),\(log.medicationName),\(dosage),\(status),\(cleanNotes)\n"
        }
        
        let fileName = "MedicationHistory_\(DateFormatter.fileNameFormatter.string(from: Date())).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    private func createPDFFile() -> URL? {
        let logs = filteredLogs
        guard !logs.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.takenAt) }
        let sortedDates = grouped.keys.sorted(by: >)
        let sectionDateFormatter = DateFormatter()
        sectionDateFormatter.dateStyle = .long
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let coverageFormatter = DateFormatter()
        coverageFormatter.dateStyle = .medium
        let exportedOnFormatter = DateFormatter()
        exportedOnFormatter.dateStyle = .long
        exportedOnFormatter.timeStyle = .short
        
        let coverageText: String
        if let earliest = logs.last?.takenAt, let latest = logs.first?.takenAt {
            coverageText = "Covers \(coverageFormatter.string(from: earliest)) – \(coverageFormatter.string(from: latest))"
        } else {
            coverageText = "Generated on \(coverageFormatter.string(from: Date()))"
        }
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        let dateBadgeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        
        let pdfData = renderer.pdfData { context in
            var currentY = margin
            
            func drawHeader() {
                let title = NSAttributedString(string: "Medication History Report", attributes: titleAttributes)
                let titleHeight = height(for: title, width: contentWidth)
                title.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: titleHeight))
                currentY += titleHeight + 2
                
                let subtitle = NSAttributedString(string: coverageText, attributes: subtitleAttributes)
                let subtitleHeight = height(for: subtitle, width: contentWidth)
                subtitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: subtitleHeight))
                currentY += subtitleHeight + 12
                
                context.cgContext.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.move(to: CGPoint(x: margin, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
                context.cgContext.strokePath()
                currentY += 18
            }
            
            func beginPage() {
                context.beginPage()
                currentY = margin
                drawHeader()
            }
            
            func ensureSpace(for blockHeight: CGFloat) {
                if currentY + blockHeight > pageRect.height - margin {
                    beginPage()
                }
            }
            
            func drawSummaryCard() {
                let takenCount = logs.filter { !$0.skipped }.count
                let skippedCount = logs.filter { $0.skipped }.count
                let uniqueMedications = Set(logs.map { $0.medicationName }).count
                let summaryText = """
                Entries logged: \(logs.count)
                Doses taken: \(takenCount)
                Doses skipped: \(skippedCount)
                Medications tracked: \(uniqueMedications)
                Exported on: \(exportedOnFormatter.string(from: Date()))
                """
                let summaryAttributed = NSAttributedString(string: summaryText, attributes: bodyAttributes)
                let textHeight = height(for: summaryAttributed, width: contentWidth - 40)
                let cardHeight = textHeight + 28
                ensureSpace(for: cardHeight)
                
                let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: cardHeight)
                let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 14)
                UIColor(white: 0.98, alpha: 1).setFill()
                cardPath.fill()
                UIColor(white: 0.85, alpha: 1).setStroke()
                cardPath.lineWidth = 0.6
                cardPath.stroke()
                
                summaryAttributed.draw(in: cardRect.insetBy(dx: 20, dy: 14))
                currentY += cardHeight + 24
            }
            
            func drawLogEntry(_ log: MedicationLog) {
                let dosageText = log.recordedDosageWithUnit
                
                let dateString = sectionDateFormatter.string(from: log.takenAt)
                let timeString = timeFormatter.string(from: log.takenAt)
                var lines: [String] = []
                lines.append("Date: \(dateString)")
                lines.append("Time: \(timeString)")
                lines.append("Medication: \(log.medicationName)")
                lines.append("Amount: \(dosageText.isEmpty ? "—" : dosageText)")
                
                let pillsText: String
                if log.skipped {
                    pillsText = "Skipped"
                } else if let pills = log.pillsConsumed, pills > 0 {
                    pillsText = pills == 1 ? "1 pill" : "\(pills) pills"
                } else {
                    pillsText = "Not recorded"
                }
                lines.append("Pills Taken: \(pillsText)")
                
                let noteParts = splitNotesAndSideEffects(for: log)
                if let notesText = noteParts.notes {
                    lines.append("Notes: \(notesText)")
                }
                if let checkInText = noteParts.checkInNotes {
                    if noteParts.notes != nil {
                        lines.append("---")
                    }
                    lines.append("Check-in Notes: \(checkInText)")
                }

                if let feeling = log.feelingRating {
                    lines.append("Feeling Rating: \(feeling)/5")
                }
                if let sideEffects = log.sideEffectSeverity {
                    lines.append("Side Effects Rating: \(sideEffects)/5")
                }
                if let focus = log.focusRating {
                    lines.append("Focus Rating: \(focus)/5")
                }
                
                if let sideEffectsText = noteParts.sideEffects {
                    lines.append("Side Effects: \(sideEffectsText)")
                }
                
                let entryAttributed = NSAttributedString(string: lines.joined(separator: "\n"), attributes: bodyAttributes)
                let textHeight = height(for: entryAttributed, width: contentWidth - 24)
                let cardHeight = textHeight + 22
                ensureSpace(for: cardHeight)
                
                let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: cardHeight)
                let entryPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 12)
                UIColor(white: 0.99, alpha: 1).setFill()
                entryPath.fill()
                UIColor(white: 0.88, alpha: 1).setStroke()
                entryPath.lineWidth = 0.6
                entryPath.stroke()
                
                entryAttributed.draw(in: cardRect.insetBy(dx: 12, dy: 11))
                currentY += cardHeight + 10
            }
            
            func drawDateSection(for date: Date) {
                let dateString = sectionDateFormatter.string(from: date)
                let attributedDate = NSAttributedString(string: dateString, attributes: dateBadgeAttributes)
                let badgeHeight: CGFloat = 28
                let textRect = attributedDate.boundingRect(
                    with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let calculatedWidth = min(textRect.width + 24, contentWidth)
                ensureSpace(for: badgeHeight + 8)
                let badgeRect = CGRect(x: margin, y: currentY, width: calculatedWidth, height: badgeHeight)
                let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 8)
                UIColor(red: 0.92, green: 0.95, blue: 0.93, alpha: 1).setFill()
                badgePath.fill()
                attributedDate.draw(in: badgeRect.insetBy(dx: 12, dy: 6))
                currentY += badgeHeight + 6
                
                for log in (grouped[date] ?? []).sorted(by: { $0.takenAt > $1.takenAt }) {
                    drawLogEntry(log)
                }
                currentY += 6
            }
            
            beginPage()
            drawSummaryCard()
            for date in sortedDates {
                drawDateSection(for: date)
            }
        }
        
        let fileName = "MedicationHistory_Full_\(DateFormatter.fileNameFormatter.string(from: Date())).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Error writing PDF file: \(error)")
            return nil
        }
    }
    
    private func height(for attributedString: NSAttributedString, width: CGFloat) -> CGFloat {
        let bounds = attributedString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounds.height)
    }
    
    private func splitNotesAndSideEffects(for log: MedicationLog) -> (notes: String?, checkInNotes: String?, sideEffects: String?) {
        guard var raw = log.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (nil, nil, nil)
        }
        var sideEffectsPart: String?
        if let range = raw.range(of: "Side effects:", options: [.caseInsensitive]) {
            let after = raw[range.upperBound...]
            sideEffectsPart = after.trimmingCharacters(in: .whitespacesAndNewlines)
            raw = String(raw[..<range.lowerBound])
        }
        let paragraphs = raw
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var generalNote: String?
        var checkInNote: String?
        if paragraphs.count > 1 {
            generalNote = paragraphs.first
            checkInNote = paragraphs.dropFirst().joined(separator: "\n\n")
        } else if let first = paragraphs.first {
            if log.feelingRating != nil || log.focusRating != nil || log.sideEffectSeverity != nil {
                checkInNote = first
            } else {
                generalNote = first
            }
        }
        return (
            generalNote?.isEmpty == true ? nil : generalNote,
            checkInNote?.isEmpty == true ? nil : checkInNote,
            sideEffectsPart?.isEmpty == true ? nil : sideEffectsPart
        )
    }
}

private struct HistoryControlButton: View {
    let icon: String
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundColor(Color(hex: "#E8E8E0"))
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                )
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    .kerning(0.6)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                    .lineLimit(1)

                if let detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .opacity(0.35)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HistoryEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            
            Text("No history yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("Log a medication to see your dose timeline, notes, and progress.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#if DEBUG
struct MedicationHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        MedicationHistoryView()
            .environmentObject(MedicationStore.previewStore())
    }
}
#endif
