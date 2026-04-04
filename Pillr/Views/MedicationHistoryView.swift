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
    @State private var logToEdit: MedicationLog?
    @State private var showingManualEntrySheet = false
    
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
        let names = Set(store.logs.filter { $0.isDoseLog }.map { $0.medicationName })
        return ["All"] + names.sorted()
    }

    private var manuallyAddableMedications: [Medication] {
        store.medications
            .filter { !$0.isDeleted }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
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
            return matchesMedication && matchesSkipFilter && inRange && log.isDoseLog && !log.hiddenFromHistory
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
                Color.pillrPrimary
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        if !isModal {
                            headerActionsSection
                        }
                        statsSection
                        
                        if groupedLogs.isEmpty {
                            HistoryEmptyState()
                        } else {
                            timelineSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isModal ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(Color.pillrSecondary)
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
                            .foregroundColor(Color.pillrSecondary)
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
        .sheet(item: $logToEdit) { log in
            LogDateEditSheet(
                log: log,
                onCancel: { logToEdit = nil },
                onSave: { newDate in
                    store.updateLogDate(log, newDate: newDate)
                    logToEdit = nil
                }
            )
        }
        .sheet(isPresented: $showingManualEntrySheet) {
            ManualHistoryEntrySheet(
                medications: manuallyAddableMedications,
                onCancel: { showingManualEntrySheet = false },
                onSave: { medication, entryDate, skipped in
                    store.addManualHistoryEntry(for: medication, at: entryDate, skipped: skipped)
                    let entryDay = Calendar.current.startOfDay(for: entryDate)
                    if entryDay < Calendar.current.startOfDay(for: selectedStartDate) {
                        selectedStartDate = entryDate
                    }
                    if entryDate > selectedEndDate {
                        selectedEndDate = entryDate
                    }
                    if selectedMedication != "All" && selectedMedication != medication.name {
                        selectedMedication = "All"
                    }
                    showingManualEntrySheet = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedStartDate) { _, newValue in
            if selectedEndDate < newValue {
                selectedEndDate = newValue
            }
        }
        .onChange(of: selectedEndDate) { _, newValue in
            if newValue < selectedStartDate {
                selectedStartDate = newValue
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("History")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
            
            Text("Logged doses: \(rangeTakenCount)  •  Adherence: \(rangeAdherenceRate)")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.pillrSecondary.opacity(0.65))
        }
        .padding(.top, 4)
    }

    private var headerActionsSection: some View {
        HStack(spacing: 12) {
            addControl
            includeSkippedControl
            exportControl
        }
    }
    
    private var dateRangeFullScreen: some View {
        NavigationStack {
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
                    .foregroundColor(Color.pillrSecondary)
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
                        .foregroundColor(Color.pillrBackground)
                }

                VStack(spacing: 12) {
                    dateSelectionCard(
                        label: "From",
                        selectionText: MedicationHistoryView.rangeDateFormatter.string(from: selectedStartDate)
                    ) {
                        DatePicker("", selection: $selectedStartDate, in: ...selectedEndDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .tint(Color.pillrBackground)
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
                            .tint(Color.pillrBackground)
                            .scaleEffect(y: 0.8, anchor: .center)
                            .frame(height: 120)
                    }
                }

                HStack(spacing: 10) {
                    Label("\(rangeDaysDisplayed) days selected", systemImage: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                    Spacer()
                    Text("\(rangeTakenCount) logged • \(rangeNotesCount) notes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.pillrSecondary)
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
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.pillrPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.pillrBackground)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
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
                    .foregroundColor(Color.pillrSecondary.opacity(0.8))
                Text(selectionText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.pillrBackground)
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
                        .foregroundColor(Color.pillrSecondary)
                    Text("Jump to a recent window")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.pillrSecondary.opacity(0.7))
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(activePresetLabel ?? "Custom")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#7FE3FF"))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.pillrSecondary)
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
                .foregroundColor(includeSkipped ? Color.pillrSecondary : Color.white.opacity(0.7))
                .accessibilityLabel(includeSkipped ? "Exclude skipped doses" : "Include skipped doses")
        }
    }

    private var includeSkippedControl: some View {
        Menu {
            Button(includeSkipped ? "Hide skipped medication" : "Show skipped medication") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    includeSkipped.toggle()
                }
            }
        } label: {
            HistoryActionButton(
                icon: includeSkipped ? "checkmark.circle.fill" : "circle",
                title: includeSkipped ? "Skipped shown" : "Skipped hidden"
            )
        }
        .buttonStyle(.plain)
    }

    private var exportControl: some View {
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
            HistoryActionButton(
                icon: "square.and.arrow.up",
                title: "Export"
            )
        }
        .buttonStyle(.plain)
        .disabled(filteredLogs.isEmpty)
    }

    private var addControl: some View {
        Button {
            showingManualEntrySheet = true
        } label: {
            HistoryActionButton(
                icon: "plus",
                title: "Add"
            )
        }
        .buttonStyle(.plain)
        .disabled(manuallyAddableMedications.isEmpty)
    }
    
    private var statsSection: some View {
        GlassContainer(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        dateRangeControl
                        filterControl
                    }

                    VStack(spacing: 12) {
                        dateRangeControl
                        filterControl
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
                detail: nil
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
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedLogs, id: \.date) { date, logs in
                VStack(alignment: .leading, spacing: 12) {
                    dayHeader(for: date)
                    
                    VStack(spacing: 18) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                        MedicationTimelineRow(
                            log: log,
                            iconName: log.recordedIconName,
                            dosageText: log.recordedDosageWithUnit.isEmpty ? nil : log.recordedDosageWithUnit,
                            showDoseChip: log.recordedHasMultipleReminders,
                            timeText: MedicationHistoryView.timeFormatter.string(from: log.takenAt),
                            isLast: index == logs.count - 1,
                            onDelete: {
                                store.hideDoseLogFromHistory(log)
                            }
                        )
                        }
                    }
                }
            }
        }
        .padding(.top, 28)
    }

    private func dayHeader(for date: Date) -> some View {
        HStack(spacing: 12) {
            Text(dayLabel(for: date))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.pillrBackground)
                .fixedSize(horizontal: true, vertical: false)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            Text(dayHeaderRightLabel(for: date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.pillrSecondary.opacity(0.72))
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func dayHeaderRightLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return MedicationHistoryView.dayFormatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
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
    let onDelete: () -> Void
    @State private var showingDeleteConfirm = false
    @State private var showingActionMenu = false

    private var hasSupportingDetails: Bool {
        (log.reminderIndex != nil && showDoseChip) ||
        log.feelingRating != nil ||
        log.focusRating != nil ||
        log.sideEffectSeverity != nil
    }

    private var trimmedNotes: String? {
        guard let notes = log.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !notes.isEmpty else {
            return nil
        }
        return notes
    }

    private var expandedActions: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    showingDeleteConfirm = true
                }
            } label: {
                Text("Delete")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.red.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.red.opacity(0.22), lineWidth: 0.8)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var statusLabel: String {
        log.skipped ? "Skipped" : "Taken"
    }

    private var doseLabel: String? {
        guard let reminder = log.reminderIndex, showDoseChip else { return nil }
        return "Dose \(reminder + 1)"
    }

    private var statusColor: Color {
        if log.skipped {
            return Color(hex: "#8B7366")
        }
        return Color(hex: "#DDE5DF")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(log.medicationName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .lineLimit(1)

                    if let dosageText {
                        Text(dosageText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.pillrSecondary.opacity(0.72))
                    }
                }

                Spacer(minLength: 6)

                Text(timeText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.pillrSecondary.opacity(0.72))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    showingActionMenu.toggle()
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(alignment: .center, spacing: 8) {
                Text(statusLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(statusColor)

                Spacer(minLength: 8)

                if let doseLabel {
                    HistoryChip(
                        text: doseLabel,
                        tint: Color.pillrSecondary,
                        style: .subtle
                    )
                }
            }

            if showingActionMenu {
                if hasSupportingDetails {
                    VStack(alignment: .leading, spacing: 10) {
                        if let feeling = log.feelingRating {
                            detailSection(title: "Feeling", value: "\(feeling)/5")
                        }

                        if let focus = log.focusRating {
                            detailSection(title: "Focus", value: "\(focus)/5")
                        }
                        
                        if let sideEffects = log.sideEffectSeverity {
                            detailSection(title: "Side effects", value: "\(sideEffects)/5")
                        }
                    }
                }
                
                if let trimmedNotes {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.pillrBackground)

                        Text(trimmedNotes)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.pillrSecondary.opacity(0.72))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                expandedActions
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 5)
        .alert("Delete log entry?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This entry will be permanently removed from your history.")
        }
    }
}

private struct ManualHistoryEntrySheet: View {
    let medications: [Medication]
    let onCancel: () -> Void
    let onSave: (Medication, Date, Bool) -> Void

    @State private var selectedMedicationID: UUID?
    @State private var selectedDate: Date = Date()
    @State private var selectedStatus: ManualEntryStatus = .taken

    private var selectedMedication: Medication? {
        guard let selectedMedicationID else { return nil }
        return medications.first(where: { $0.id == selectedMedicationID })
    }

    private enum ManualEntryStatus: String, CaseIterable, Identifiable {
        case taken
        case skipped

        var id: String { rawValue }

        var title: String {
            rawValue.capitalized
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pillrPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Add History")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color.pillrBackground)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("MEDICATION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.pillrSecondary.opacity(0.75))

                            if medications.isEmpty {
                                Text("No medications available yet.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.pillrSecondary)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(medications) { medication in
                                        Button {
                                            selectedMedicationID = medication.id
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(medication.name)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(Color.pillrBackground)

                                                    Text(medication.dosageWithUnit)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(Color.pillrSecondary.opacity(0.75))
                                                }

                                                Spacer()

                                                Image(systemName: selectedMedicationID == medication.id ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundColor(selectedMedicationID == medication.id ? Color.pillrAccent : Color.pillrSecondary.opacity(0.6))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Color.white.opacity(selectedMedicationID == medication.id ? 0.08 : 0.035))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .stroke(Color.white.opacity(selectedMedicationID == medication.id ? 0.14 : 0.06), lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        manualEntryCard(
                            title: "Date and time",
                            subtitle: selectedMedication == nil ? "Pick a medication first" : "Choose when this happened"
                        ) {
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .tint(Color.pillrBackground)
                            .disabled(selectedMedication == nil)
                            .opacity(selectedMedication == nil ? 0.45 : 1)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                        }

                        manualEntryCard(
                            title: "Status",
                            subtitle: "Choose whether it was taken or skipped"
                        ) {
                            Picker("", selection: $selectedStatus) {
                                ForEach(ManualEntryStatus.allCases) { status in
                                    Text(status.title).tag(status)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.pillrBackground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            guard let selectedMedication else { return }
                            onSave(selectedMedication, selectedDate, selectedStatus == .skipped)
                        } label: {
                            Text("Add History")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.pillrPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.pillrBackground)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedMedication == nil)
                        .opacity(selectedMedication == nil ? 0.5 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onCancel()
                    }
                    .foregroundColor(Color.pillrSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func manualEntryCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.pillrSecondary.opacity(0.75))

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.pillrSecondary.opacity(0.72))
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct LogDateEditSheet: View {
    let log: MedicationLog
    let onCancel: () -> Void
    let onSave: (Date) -> Void
    @State private var selectedDate: Date

    init(log: MedicationLog, onCancel: @escaping () -> Void, onSave: @escaping (Date) -> Void) {
        self.log = log
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedDate = State(initialValue: log.takenAt)
    }

    var body: some View {
        NavigationStack {
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

                VStack(alignment: .leading, spacing: 16) {
                    Text("Edit Log Date")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)

                    Text(log.medicationName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.pillrSecondary)

                    DatePicker(
                        "Log time",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(Color.pillrBackground)
                    .padding(.vertical, 8)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(Color.pillrSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedDate)
                    }
                    .foregroundColor(Color.pillrBackground)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct HistoryChip: View {
    enum Style {
        case prominent
        case subtle
    }

    let text: String
    let tint: Color
    let style: Style
    
    var body: some View {
            Text(text)
                .font(.caption.weight(.medium))
        .foregroundColor(style == .prominent ? Color.pillrPrimary : Color.pillrSecondary.opacity(0.72))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 28)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(style == .prominent ? tint.opacity(0.9) : Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(style == .prominent ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private extension MedicationTimelineRow {
    func detailSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.pillrBackground)

            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.pillrSecondary.opacity(0.72))
        }
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
        
        let sortedLogs = logs.sorted { $0.takenAt > $1.takenAt }
        let startDate = min(selectedStartDate, selectedEndDate)
        let endDate = max(selectedStartDate, selectedEndDate)
        let periodFormatter = DateFormatter()
        periodFormatter.dateFormat = "d MMM yyyy"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let exportedOnFormatter = DateFormatter()
        exportedOnFormatter.dateFormat = "d MMM yyyy, h:mm a"
        let exportedTimestamp = exportedOnFormatter.string(from: Date())
            .replacingOccurrences(of: " AM", with: " am")
            .replacingOccurrences(of: " PM", with: " pm")

        var csv = "Medication History Report\n"
        csv += "Period,\"\(periodFormatter.string(from: startDate)) – \(periodFormatter.string(from: endDate))\"\n"
        csv += "Exported,\"\(exportedTimestamp)\"\n"
        csv += "Entries,\(logs.count)\n"
        csv += "Taken,\(logs.filter { !$0.skipped }.count)\n"
        csv += "Skipped,\(logs.filter { $0.skipped }.count)\n"
        csv += "\n"
        csv += "Date,Time,Medication,Dosage,Status,Manual Entry\n"
        
        for log in sortedLogs {
            let dosage = log.recordedDosageWithUnit
            let status = log.skipped ? "Skipped" : "Taken"
            let manualEntry = log.isManuallyAdded ? "Yes" : "No"
            csv += "\(csvField(dateFormatter.string(from: log.takenAt))),\(csvField(timeFormatter.string(from: log.takenAt))),\(csvField(log.medicationName)),\(csvField(dosage)),\(csvField(status)),\(manualEntry)\n"
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

    private func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    private func createPDFFile() -> URL? {
        let logs = filteredLogs
        guard !logs.isEmpty else { return nil }

        let sortedLogs = logs.sorted { $0.takenAt > $1.takenAt }
        let startDate = min(selectedStartDate, selectedEndDate)
        let endDate = max(selectedStartDate, selectedEndDate)
        let periodFormatter = DateFormatter()
        periodFormatter.dateFormat = "d MMM yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let exportedOnFormatter = DateFormatter()
        exportedOnFormatter.dateFormat = "d MMM yyyy, h:mm a"

        let pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let margin: CGFloat = 38
        let contentWidth = pageRect.width - (margin * 2)
        let takenCount = logs.filter { !$0.skipped }.count
        let skippedCount = logs.filter { $0.skipped }.count
        let uniqueMedicationNames = Array(Set(logs.map(\.medicationName))).sorted()
        let medicationsTracked = uniqueMedicationNames.count
        let reportPeriod = "Period: \(periodFormatter.string(from: startDate)) – \(periodFormatter.string(from: endDate))"
        let exportedTimestamp = exportedOnFormatter.string(from: Date())
            .replacingOccurrences(of: " AM", with: " am")
            .replacingOccurrences(of: " PM", with: " pm")
        let exportedAt = "Exported \(exportedTimestamp)"
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor(white: 0.10, alpha: 1)
        ]
        let monoLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(white: 0.48, alpha: 1)
        ]
        let monoValueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor(white: 0.28, alpha: 1)
        ]
        let summaryLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor(white: 0.28, alpha: 1)
        ]
        let summaryValueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: UIColor(white: 0.10, alpha: 1)
        ]
        let summaryValueAccentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: UIColor(red: 0.12, green: 0.62, blue: 0.46, alpha: 1)
        ]
        let headerCellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor(white: 0.48, alpha: 1)
        ]
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor(white: 0.28, alpha: 1)
        ]
        let medicationNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor(white: 0.10, alpha: 1)
        ]
        let medicationMetaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor(white: 0.50, alpha: 1)
        ]

        let pdfData = renderer.pdfData { context in
            var currentY = margin

            let tableDateWidth: CGFloat = 104
            let tableMedicationWidth: CGFloat = 215
            let tableDoseWidth: CGFloat = 82
            let tableTimeWidth: CGFloat = 96
            let tablePillsWidth = contentWidth - tableDateWidth - tableMedicationWidth - tableDoseWidth - tableTimeWidth
            let tableRowHeight: CGFloat = 54

            func drawText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any], alignment: NSTextAlignment = .left) {
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.lineBreakMode = .byTruncatingTail
                var mergedAttributes = attributes
                mergedAttributes[.paragraphStyle] = style
                NSAttributedString(string: text, attributes: mergedAttributes).draw(in: rect)
            }

            func beginPage() {
                context.beginPage()
                currentY = margin
            }

            func drawHeader(isFirstPage: Bool) {
                drawText(
                    "Medication History Report",
                    in: CGRect(x: margin, y: currentY, width: contentWidth * 0.54, height: 28),
                    attributes: titleAttributes
                )

                drawText(
                    isFirstPage ? "Patient Record" : "Patient Record • Continued",
                    in: CGRect(x: margin + contentWidth * 0.54, y: currentY + 2, width: contentWidth * 0.46, height: 14),
                    attributes: monoValueAttributes,
                    alignment: .right
                )

                currentY += 26

                if isFirstPage {
                    drawText(
                        reportPeriod,
                        in: CGRect(x: margin, y: currentY, width: contentWidth * 0.60, height: 14),
                        attributes: monoValueAttributes
                    )
                    drawText(
                        exportedAt,
                        in: CGRect(x: margin + contentWidth * 0.60, y: currentY, width: contentWidth * 0.40, height: 14),
                        attributes: monoValueAttributes,
                        alignment: .right
                    )
                    currentY += 22
                } else {
                    drawText(
                        reportPeriod,
                        in: CGRect(x: margin, y: currentY - 2, width: contentWidth, height: 12),
                        attributes: monoLabelAttributes
                    )
                    currentY += 12
                }

                context.cgContext.setStrokeColor(UIColor(white: 0.12, alpha: 1).cgColor)
                context.cgContext.setLineWidth(2)
                context.cgContext.move(to: CGPoint(x: margin, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
                context.cgContext.strokePath()
                currentY += isFirstPage ? 12 : 10
            }

            func drawSummaryCards() {
                let cardGap: CGFloat = 10
                let cardHeight: CGFloat = 76
                let cardWidth = (contentWidth - cardGap) / 2
                let cards: [(String, String, Bool)] = [
                    ("ENTRIES", "\(logs.count)", false),
                    ("TAKEN", "\(takenCount)", true),
                    ("SKIPPED", "\(skippedCount)", false),
                    ("MEDICATIONS", "\(medicationsTracked)", false)
                ]

                for (index, card) in cards.enumerated() {
                    let row = CGFloat(index / 2)
                    let column = CGFloat(index % 2)
                    let cardX = margin + column * (cardWidth + cardGap)
                    let cardY = currentY + row * (cardHeight + cardGap)
                    let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
                    let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 16)
                    UIColor(white: 0.97, alpha: 1).setFill()
                    path.fill()

                    drawText(card.0, in: CGRect(x: cardRect.minX + 14, y: cardRect.minY + 14, width: cardRect.width - 28, height: 18), attributes: summaryLabelAttributes)
                    drawText(
                        card.1,
                        in: CGRect(x: cardRect.minX + 14, y: cardRect.minY + 36, width: cardRect.width - 28, height: 24),
                        attributes: card.2 ? summaryValueAccentAttributes : summaryValueAttributes
                    )
                }

                currentY += (cardHeight * 2) + cardGap + 18
            }

            func drawTableHeader() {
                let y = currentY
                drawText("DATE", in: CGRect(x: margin, y: y, width: tableDateWidth, height: 16), attributes: headerCellAttributes)
                drawText("MEDICATION", in: CGRect(x: margin + tableDateWidth, y: y, width: tableMedicationWidth, height: 16), attributes: headerCellAttributes)
                drawText("DOSE", in: CGRect(x: margin + tableDateWidth + tableMedicationWidth, y: y, width: tableDoseWidth, height: 16), attributes: headerCellAttributes, alignment: .right)
                drawText("TIME", in: CGRect(x: margin + tableDateWidth + tableMedicationWidth + tableDoseWidth, y: y, width: tableTimeWidth, height: 16), attributes: headerCellAttributes, alignment: .right)

                currentY += 22
                context.cgContext.setStrokeColor(UIColor(white: 0.84, alpha: 1).cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: margin, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
                context.cgContext.strokePath()
                currentY += 8
            }

            func drawTableRow(_ log: MedicationLog) {
                let rowTop = currentY
                let doseText = log.recordedDosageWithUnit.isEmpty ? "—" : log.recordedDosageWithUnit
                let exportedTime = timeFormatter.string(from: log.takenAt).lowercased()

                drawText(periodFormatter.string(from: log.takenAt), in: CGRect(x: margin, y: rowTop + 8, width: tableDateWidth - 12, height: 20), attributes: cellAttributes)

                let medicationX = margin + tableDateWidth
                drawText(log.medicationName, in: CGRect(x: medicationX, y: rowTop + 6, width: tableMedicationWidth - 6, height: 18), attributes: medicationNameAttributes)

                let statusText = log.skipped ? "Skipped" : "Taken"
                drawText(statusText, in: CGRect(x: medicationX, y: rowTop + 22, width: tableMedicationWidth - 6, height: 14), attributes: medicationMetaAttributes)

                if log.isManuallyAdded {
                    drawText("Manual entry", in: CGRect(x: medicationX, y: rowTop + 34, width: tableMedicationWidth - 6, height: 14), attributes: medicationMetaAttributes)
                }

                drawText(
                    doseText,
                    in: CGRect(x: margin + tableDateWidth + tableMedicationWidth, y: rowTop + 8, width: tableDoseWidth - 8, height: 20),
                    attributes: cellAttributes,
                    alignment: .right
                )
                drawText(
                    exportedTime,
                    in: CGRect(x: margin + tableDateWidth + tableMedicationWidth + tableDoseWidth, y: rowTop + 8, width: tableTimeWidth - 8, height: 20),
                    attributes: cellAttributes,
                    alignment: .right
                )

                context.cgContext.setStrokeColor(UIColor(white: 0.88, alpha: 1).cgColor)
                context.cgContext.setLineWidth(0.8)
                context.cgContext.move(to: CGPoint(x: margin, y: rowTop + tableRowHeight - 2))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: rowTop + tableRowHeight - 2))
                context.cgContext.strokePath()

                currentY += 48
            }

            func beginReportPage(isFirstPage: Bool) {
                beginPage()
                drawHeader(isFirstPage: isFirstPage)
                if isFirstPage {
                    drawSummaryCards()
                }
                drawTableHeader()
            }

            func ensureRowSpace() {
                if currentY + tableRowHeight > pageRect.height - margin {
                    beginReportPage(isFirstPage: false)
                }
            }

            beginReportPage(isFirstPage: true)
            for log in sortedLogs {
                ensureRowSpace()
                drawTableRow(log)
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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundColor(Color.pillrBackground)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.pillrSecondary.opacity(0.7))
                    .kerning(0.45)

                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.pillrBackground)
                    .lineLimit(1)

                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.pillrSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(Color.pillrSecondary)
                .opacity(0.28)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 72)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HistoryActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.pillrBackground)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HistoryEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundColor(Color.pillrSecondary.opacity(0.7))
            
            Text("No history yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
            
            Text("Log a medication to see your dose timeline, notes, and progress.")
                .font(.system(size: 14))
                .foregroundColor(Color.pillrSecondary)
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
