//
//  DailyCheckInHistoryView.swift
//  Pillr
//
//  Created by Codex on 2025-XX-XX.
//


import SwiftUI
import UIKit

// MARK: - Premium journal styling
private enum ReflectJournalTheme {
    // Base palette
    static var pageTop: Color { Color(hex: "#3E483F") }
    static var pageBottom: Color { Color(hex: "#303830") }

    static var textPrimary: Color { Color(hex: "#E8E8E0") }
    static var textSecondary: Color { Color(hex: "#C7C7BD").opacity(0.72) }
    static var textTertiary: Color { Color(hex: "#C7C7BD").opacity(0.52) }

    // Paper
    static var sheetFill: Color { Color.white.opacity(AppTheme.shared.mode == .dark ? 0.06 : 0.075) }
    static var sheetFillExpanded: Color { Color.white.opacity(AppTheme.shared.mode == .dark ? 0.08 : 0.09) }
    static var sheetHighlight: Color { Color.white.opacity(AppTheme.shared.mode == .dark ? 0.12 : 0.14) }

    // Accents
    static var accent: Color { Color(hex: "#E1D6C5") }
    static var progressTrack: Color { Color.white.opacity(AppTheme.shared.mode == .dark ? 0.12 : 0.16) }

    static var pageBackground: some View {
        LinearGradient.pillrBackground
    }
}

private struct JournalTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 30, weight: .semibold))
            .foregroundColor(ReflectJournalTheme.textPrimary)
            .tracking(0.2)
    }
}

private struct JournalSubtitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(ReflectJournalTheme.textTertiary)
    }
}

private struct JournalSectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ReflectJournalTheme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.9)
    }
}

private struct JournalSheet: ViewModifier {
    let isExpanded: Bool

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = 20
        content
            .padding(.horizontal, 16)
            .padding(.vertical, isExpanded ? 16 : 14)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isExpanded ? ReflectJournalTheme.sheetFillExpanded : ReflectJournalTheme.sheetFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(ReflectJournalTheme.sheetHighlight.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(isExpanded ? 0.12 : 0.08), radius: isExpanded ? 10 : 8, x: 0, y: isExpanded ? 6 : 5)
    }
}

private extension View {
    func journalTitle() -> some View { modifier(JournalTitle()) }
    func journalSubtitle() -> some View { modifier(JournalSubtitle()) }
    func journalSectionHeader() -> some View { modifier(JournalSectionHeader()) }
    func journalSheet(isExpanded: Bool) -> some View { modifier(JournalSheet(isExpanded: isExpanded)) }
}

struct DailyCheckInHistoryView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    let isModal: Bool
    @State private var showingQuickCheckIn = false
    @State private var showingPremiumUpgrade = false
    @State private var editingLog: MedicationLog?
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingDateRangeSheet = false
    @State private var selectedStartDate: Date = Date()
    @State private var selectedEndDate: Date = Date()
    @State private var hasCustomDateFilter = false
    @State private var isResettingRange = false

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    init(isModal: Bool = false) {
        self.isModal = isModal
    }

    private var isPremiumActive: Bool {
        storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser()
    }

    private var selectableMedications: [Medication] {
        let active = store.activeMedications.filter { !$0.isDeleted }
        let calendar = Calendar.current
        let today = Date()
        let loggedMedicationIDs = Set(store.logs.filter { log in
            log.isDoseLog && calendar.isDate(log.takenAt, inSameDayAs: today)
        }.map { $0.medicationID })
        return active.filter { loggedMedicationIDs.contains($0.logIdentifier) }
    }

    private var defaultMedicationForCheckIn: Medication? {
        selectableMedications.first
    }

    private var checkInLogs: [MedicationLog] {
        store.logs
            .filter { $0.isDailyCheckIn }
            .sorted { $0.takenAt > $1.takenAt }
    }

    private var filteredCheckInLogs: [MedicationLog] {
        let start = min(selectedStartDate, selectedEndDate)
        let end = max(selectedStartDate, selectedEndDate)
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: start)
        let rangeEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? calendar.startOfDay(for: end).addingTimeInterval(86399)

        return checkInLogs.filter { log in
            log.takenAt >= rangeStart && log.takenAt <= rangeEnd
        }
    }

    private var groupedCheckIns: [(date: Date, logs: [MedicationLog])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredCheckInLogs) { calendar.startOfDay(for: $0.takenAt) }

        return groups.keys.sorted(by: >).map { date in
            let logsForDay = groups[date]?.sorted(by: { $0.takenAt > $1.takenAt }) ?? []
            return (date, logsForDay)
        }
    }

    private var earliestCheckInDate: Date? {
        checkInLogs.last?.takenAt
    }

    private var latestCheckInDate: Date? {
        checkInLogs.first?.takenAt
    }

    private var dateRangeLabel: String {
        guard let earliestCheckInDate, let latestCheckInDate else {
            return "All time"
        }
        let calendar = Calendar.current
        let earliestStart = calendar.startOfDay(for: earliestCheckInDate)
        let latestEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: latestCheckInDate) ?? latestCheckInDate
        let start = min(selectedStartDate, selectedEndDate)
        let end = max(selectedStartDate, selectedEndDate)

        if start <= earliestStart && end >= latestEnd {
            return "All time"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private var last7DayStats: (avgOverall: String, bestDay: String, worstDay: String)? {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let rangeStart = calendar.startOfDay(for: start)
        let rangeEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end

        let recentLogs = checkInLogs.filter { log in
            guard log.takenAt >= rangeStart && log.takenAt <= rangeEnd else { return false }
            let rating = log.feelingRating ?? 0
            return rating > 0
        }

        guard !recentLogs.isEmpty else { return nil }

        let total = recentLogs.reduce(0) { $0 + ($1.feelingRating ?? 0) }
        let avg = Double(total) / Double(recentLogs.count)
        let avgText = String(format: "%.1f/5", avg)

        let grouped = Dictionary(grouping: recentLogs) { calendar.startOfDay(for: $0.takenAt) }
        let dayAverages: [(date: Date, avg: Double)] = grouped.compactMap { date, logs in
            let ratings = logs.compactMap { $0.feelingRating }.filter { $0 > 0 }
            guard !ratings.isEmpty else { return nil }
            let dayAvg = Double(ratings.reduce(0, +)) / Double(ratings.count)
            return (date, dayAvg)
        }

        guard let best = dayAverages.max(by: { $0.avg < $1.avg }),
              let worst = dayAverages.min(by: { $0.avg < $1.avg }) else {
            return (avgText, "—", "—")
        }

        return (avgText, dayLabel(for: best.date), dayLabel(for: worst.date))
    }

    var body: some View {
        NavigationView {
            ZStack {
                ReflectJournalTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if isPremiumActive {
                            headerSection
                        }
                        if !isPremiumActive {
                            reflectionInfoCard
                        }

                        if groupedCheckIns.isEmpty {
                            if checkInLogs.isEmpty {
                                if isPremiumActive {
                                    DailyCheckInEmptyState()
                                }
                            } else {
                                DailyCheckInFilteredEmptyState()
                            }
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
                    Text("Reflection")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textPrimary)
                        .tracking(0.2)
                }
                if isModal {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(ReflectJournalTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isPremiumActive {
                            showingDateRangeSheet = true
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textSecondary)
                    }
                    .disabled(checkInLogs.isEmpty && isPremiumActive)
                    .accessibilityLabel("Filter reflections")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            exportReflectionsAsCSV()
                        } label: {
                            Label("Export CSV", systemImage: "doc.text")
                        }

                        Button {
                            exportReflectionsAsPDF()
                        } label: {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textSecondary)
                    }
                    .disabled(checkInLogs.isEmpty && isPremiumActive)
                    .accessibilityLabel("Export reflections")
                    .onTapGesture {
                        if !isPremiumActive {
                            showingPremiumUpgrade = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isPremiumActive {
                            showingQuickCheckIn = true
                        } else {
                            showingPremiumUpgrade = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textSecondary)
                    }
                    .disabled(defaultMedicationForCheckIn == nil && isPremiumActive)
                    .accessibilityLabel("New Reflection")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showingDateRangeSheet) {
            dateRangeSheet
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(StoreManager.shared)
        }
        .sheet(isPresented: $showingQuickCheckIn) {
            if let medication = defaultMedicationForCheckIn {
                LogMedicationView(
                    medicationToLog: medication,
                    isDailyCheckIn: true,
                    checkInLogID: nil,
                    allowsMedicationSelection: true
                )
                .environmentObject(store)
            }
        }
        .sheet(item: $editingLog) { log in
            if let medication = store.findMedication(with: log.medicationID) {
                LogMedicationView(
                    medicationToLog: medication,
                    isDailyCheckIn: true,
                    checkInLogID: log.id,
                    allowsMedicationSelection: false
                )
                .environmentObject(store)
            } else {
                VStack(spacing: 12) {
                    Text("Medication unavailable")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    Text("This reflection entry can't be edited right now.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
                .padding(24)
                .background(LinearGradient.pillrBackground.ignoresSafeArea())
            }
        }
        .onAppear {
            if earliestCheckInDate != nil && latestCheckInDate != nil {
                resetToAllTime()
            } else {
                selectedStartDate = Date()
                selectedEndDate = Date()
            }
        }
        .onChange(of: selectedStartDate) { _, newValue in
            if selectedEndDate < newValue {
                selectedEndDate = newValue
            }
            if showingDateRangeSheet && !isResettingRange {
                hasCustomDateFilter = true
            }
        }
        .onChange(of: selectedEndDate) { _, newValue in
            if newValue < selectedStartDate {
                selectedStartDate = newValue
            }
            if showingDateRangeSheet && !isResettingRange {
                hasCustomDateFilter = true
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reflection")
                    .journalTitle()

                Text("\(filteredCheckInLogs.count) \(filteredCheckInLogs.count == 1 ? "entry" : "entries") logged")
                    .journalSubtitle()

                if hasCustomDateFilter {
                    Text(dateRangeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textSecondary)
                }
            }

            Spacer()

            if let stats = last7DayStats {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Avg Overall \(stats.avgOverall)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textPrimary)

                    Text("Best day \(stats.bestDay)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ReflectJournalTheme.textSecondary)

                    Text("Worst day \(stats.worstDay)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ReflectJournalTheme.textSecondary)
                }
                .multilineTextAlignment(.trailing)
                .padding(.top, -2)
            }
        }
        .padding(.top, 16)
    }

    private var reflectionInfoCard: some View {
            VStack(alignment: .center, spacing: 12) {
            Text("Reflection helps you understand how your medications affect your day by tracking mood, focus, and side effects over time.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textPrimary)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                VStack(alignment: .leading, spacing: 4) {
                Text("- AI powered reflection summaries")
                Text("- CSV and PDF export")
                Text("- Date filtering and history view")
                Text("- Custom reminders")
            }
                .font(.system(size: 13))
                .foregroundColor(ReflectJournalTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                Text("Example Reflection entry")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ReflectJournalTheme.textSecondary)
                    .italic()
                Image("Reflection Example")
                    .resizable()
                    .scaledToFit()
                .frame(maxWidth: 260)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            Button {
                showingPremiumUpgrade = true
            } label: {
                Text("Unlock Premium to Start")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E2620"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.pillrAccent)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Unlock Premium to Start")
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedCheckIns, id: \.date) { date, logs in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(dayLabel(for: date))
                            .journalSectionHeader()
                    }

                    VStack(spacing: 18) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                            DailyCheckInTimelineRow(
                                log: log,
                                timeText: DailyCheckInHistoryView.timeFormatter.string(from: log.takenAt),
                                isLast: index == logs.count - 1,
                                onEdit: {
                                    editingLog = log
                                },
                                onDelete: {
                                    store.deleteLog(log)
                                }
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
            return DailyCheckInHistoryView.dayFormatter.string(from: date)
        }
    }

    private var dateRangeSheet: some View {
        NavigationView {
            ZStack {
                ReflectJournalTheme.pageBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Date range")
                        .journalTitle()

                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("Start", selection: $selectedStartDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .tint(ReflectJournalTheme.accent)

                        DatePicker("End", selection: $selectedEndDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .tint(ReflectJournalTheme.accent)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ReflectJournalTheme.sheetFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ReflectJournalTheme.sheetHighlight.opacity(0.6), lineWidth: 1)
                            )
                    )

                    HStack(spacing: 10) {
                        Button("Last 7 days") {
                            applyPresetRange(days: 7)
                        }
                        Button("Last 30 days") {
                            applyPresetRange(days: 30)
                        }
                        Button("All time") {
                            resetToAllTime()
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textPrimary)
                    .padding(.top, 4)

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDateRangeSheet = false
                    }
                    .foregroundColor(ReflectJournalTheme.textSecondary)
                }
            }
        }
    }

    private func applyPresetRange(days: Int) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -max(1, days - 1), to: end) ?? end
        selectedStartDate = start
        selectedEndDate = end
        hasCustomDateFilter = true
    }

    private func resetToAllTime() {
        guard let earliest = earliestCheckInDate, let latest = latestCheckInDate else { return }
        isResettingRange = true
        selectedStartDate = earliest
        selectedEndDate = latest
        hasCustomDateFilter = false
        DispatchQueue.main.async {
            isResettingRange = false
        }
    }

    private func exportReflectionsAsCSV() {
        guard let url = createReflectionCSVFile() else { return }
        shareItems = [url]
        showingShareSheet = true
    }

    private func exportReflectionsAsPDF() {
        guard let url = createReflectionPDFFile() else { return }
        shareItems = [url]
        showingShareSheet = true
    }

    private func createReflectionCSVFile() -> URL? {
        let logs = filteredCheckInLogs
        guard !logs.isEmpty else { return nil }

        var csv = "Date,Time,Medication,Overall,Focus,SideEffectsSeverity,Mood,ReflectionSummary,Notes,CheckInNotes,SideEffects\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        for log in logs {
            let noteParts = splitNotesAndSideEffects(for: log)
            let summary = log.reflectionSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let notes = noteParts.notes ?? ""
            let checkInNotes = noteParts.checkInNotes ?? ""
            let sideEffects = noteParts.sideEffects ?? ""
            let mood = noteParts.mood ?? ""
            let fields = [
                dateFormatter.string(from: log.takenAt),
                timeFormatter.string(from: log.takenAt),
                log.medicationName,
                ratingDisplay(log.feelingRating),
                ratingDisplay(log.focusRating),
                ratingDisplay(log.sideEffectSeverity),
                mood,
                summary,
                notes,
                checkInNotes,
                sideEffects
            ]
            let row = fields.map { escapeCSVField($0) }.joined(separator: ",")
            csv += "\(row)\n"
        }

        let fileName = "ReflectionNotes_\(DateFormatter.fileNameFormatter.string(from: Date())).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing reflection CSV file: \(error)")
            return nil
        }
    }

    private func createReflectionPDFFile() -> URL? {
        let logs = filteredCheckInLogs
        guard !logs.isEmpty else { return nil }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.takenAt) }
        let sortedDates = grouped.keys.sorted(by: >)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let exportedOnFormatter = DateFormatter()
        exportedOnFormatter.dateStyle = .long
        exportedOnFormatter.timeStyle = .short

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        let dateHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let entryTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        let pdfData = renderer.pdfData { context in
            var currentY = margin

            func beginPage() {
                context.beginPage()
                currentY = margin
            }

            func drawText(_ attributedString: NSAttributedString, spacingAfter: CGFloat = 0) {
                let height = height(for: attributedString, width: contentWidth)
                if currentY + height > pageRect.height - margin {
                    beginPage()
                }
                attributedString.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: height))
                currentY += height + spacingAfter
            }

            beginPage()
            drawText(NSAttributedString(string: "Reflection Notes Export", attributes: titleAttributes), spacingAfter: 4)
            let exportedOn = "Exported on \(exportedOnFormatter.string(from: Date()))"
            drawText(NSAttributedString(string: exportedOn, attributes: subtitleAttributes), spacingAfter: 12)

            for date in sortedDates {
                let dateHeader = NSAttributedString(string: dateFormatter.string(from: date), attributes: dateHeaderAttributes)
                drawText(dateHeader, spacingAfter: 6)

                let entries = (grouped[date] ?? []).sorted(by: { $0.takenAt > $1.takenAt })
                for log in entries {
                    let headerText = "\(timeFormatter.string(from: log.takenAt)) • \(log.medicationName)"
                    drawText(NSAttributedString(string: headerText, attributes: entryTitleAttributes), spacingAfter: 4)

                    let ratingsText = "Overall: \(ratingDisplay(log.feelingRating))  Focus: \(ratingDisplay(log.focusRating))  Side effects: \(ratingDisplay(log.sideEffectSeverity))"
                    drawText(NSAttributedString(string: ratingsText, attributes: bodyAttributes), spacingAfter: 4)

                    let noteParts = splitNotesAndSideEffects(for: log)
                    if let mood = noteParts.mood?.trimmingCharacters(in: .whitespacesAndNewlines), !mood.isEmpty {
                        drawText(NSAttributedString(string: "Mood: \(mood)", attributes: bodyAttributes), spacingAfter: 4)
                    }
                    if let summary = log.reflectionSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                        drawText(NSAttributedString(string: "Summary: \(summary)", attributes: bodyAttributes), spacingAfter: 4)
                    }
                    if let notes = noteParts.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        drawText(NSAttributedString(string: "Notes: \(notes)", attributes: bodyAttributes), spacingAfter: 4)
                    }
                    if let checkInNotes = noteParts.checkInNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !checkInNotes.isEmpty {
                        drawText(NSAttributedString(string: "Check-in: \(checkInNotes)", attributes: bodyAttributes), spacingAfter: 4)
                    }
                    if let sideEffects = noteParts.sideEffects?.trimmingCharacters(in: .whitespacesAndNewlines), !sideEffects.isEmpty {
                        drawText(NSAttributedString(string: "Side effects: \(sideEffects)", attributes: bodyAttributes), spacingAfter: 8)
                    } else {
                        currentY += 8
                    }
                }
            }
        }

        let fileName = "ReflectionNotes_\(DateFormatter.fileNameFormatter.string(from: Date())).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Error writing reflection PDF file: \(error)")
            return nil
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private func ratingDisplay(_ value: Int?) -> String {
        guard let value, value > 0 else { return "—" }
        let clamped = max(0, min(value, 5))
        return "\(clamped)/5"
    }

    private func height(for attributedString: NSAttributedString, width: CGFloat) -> CGFloat {
        let bounds = attributedString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounds.height)
    }

}

private struct DailyCheckInTimelineRow: View {
    let log: MedicationLog
    let timeText: String
    let isLast: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isExpanded = true
    @State private var showingDeleteConfirm = false

    private var noteParts: (notes: String?, checkInNotes: String?, sideEffects: String?, mood: String?) {
        splitNotesAndSideEffects(for: log)
    }

    private var expandedNote: String? {
        let parts = [noteParts.notes, noteParts.checkInNotes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }

    private var reflectionSummary: String? {
        let summary = log.reflectionSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary?.isEmpty == true ? nil : summary
    }

    private var collapsedSummary: String? {
        reflectionSummary ?? expandedNote
    }

    private var feelingDisplay: String {
        guard let feeling = log.feelingRating, feeling > 0 else { return "Not set" }
        return "\(feeling)/5"
    }

    private var sideEffectChips: [String] {
        guard let sideEffects = noteParts.sideEffects, !sideEffects.isEmpty else { return [] }
        return sideEffects
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var medicationName: String {
        let trimmedName = log.medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Medication" : trimmedName
    }

    private var headerTapHeight: CGFloat {
        48
    }

    private var longPressHint: some View {
        VStack(spacing: 6) {
            Text("Long press to edit or delete")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(ReflectJournalTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 6) {
                let dotValue = CGFloat(max(0, min(log.feelingRating ?? 0, 5))) / 5.0
                Circle()
                    .fill(Color.white.opacity(0.20 + (0.35 * dotValue)))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)

                Rectangle()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 0.6)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .alignmentGuide(VerticalAlignment.center) { $0[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: 12) {
                if isExpanded {
                    HStack(alignment: .firstTextBaseline) {
                        Text(medicationName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textPrimary)

                        Spacer()

                        Text(timeText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReflectJournalTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: headerTapHeight)

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    if let reflectionSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Upon Reflection")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)

                            Text(reflectionSummary)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ReflectJournalTheme.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        DailyCheckInScaleView(
                            label: "Helped overall",
                            value: log.feelingRating,
                            isHero: true,
                            showValue: true,
                            layout: .stacked
                        )

                        if let focus = log.focusRating {
                            DailyCheckInScaleView(
                                label: "Focus level",
                                value: focus,
                                isHero: false,
                                showValue: true,
                                layout: .stacked
                            )
                        }

                        if let sideEffects = log.sideEffectSeverity {
                            DailyCheckInScaleView(
                                label: "Side-effect impact",
                                value: sideEffects,
                                isHero: false,
                                showValue: true,
                                layout: .stacked
                            )
                        }
                    }

                    if let mood = noteParts.mood?.trimmingCharacters(in: .whitespacesAndNewlines), !mood.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mood overall")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)

                            Text(mood)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ReflectJournalTheme.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let expandedNote {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)

                            Text(expandedNote)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ReflectJournalTheme.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !sideEffectChips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Side effects picked")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)

                            DailyCheckInFlowLayout(spacing: 6) {
                                ForEach(sideEffectChips, id: \.self) { effect in
                                    DailyCheckInTag(text: effect)
                                }
                            }
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.vertical, 2)

                    longPressHint
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(medicationName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ReflectJournalTheme.textSecondary)
                                .lineLimit(1)

                            Text(collapsedSummary ?? "Reflection logged")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textPrimary)
                                .lineLimit(2)
                                .truncationMode(.tail)

                            HStack(spacing: 10) {
                                if log.focusRating != nil {
                                    DailyCheckInMiniMetric(label: "Focus", value: log.focusRating)
                                        .frame(maxWidth: .infinity)
                                }

                                if log.sideEffectSeverity != nil {
                                    DailyCheckInMiniMetric(label: "Side effects", value: log.sideEffectSeverity)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        Spacer(minLength: 6)

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Overdall Day")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)

                            Text(feelingDisplay)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ReflectJournalTheme.accent)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .journalSheet(isExpanded: isExpanded)
            .frame(minHeight: isExpanded ? nil : 110)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contextMenu {
                if isExpanded {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Reflection", systemImage: "square.and.pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .alert("Delete?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This reflection will be permanently deleted.")
            }
        }
    }
}

// Compact metric bar for collapsed card
private struct DailyCheckInMiniMetric: View {
    let label: String
    let value: Int?
    let maxValue: Int

    init(label: String, value: Int?, maxValue: Int = 5) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
    }

    var body: some View {
        let clampedValue = max(0, min(value ?? 0, maxValue))
        let fraction = CGFloat(clampedValue) / CGFloat(maxValue)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 6)

                Text(value == nil ? "—" : "\(clampedValue)/\(maxValue)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(ReflectJournalTheme.progressTrack)

                    Capsule(style: .continuous)
                        .fill(ReflectJournalTheme.accent)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct DailyCheckInScaleView: View {
    let label: String
    let value: Int?
    let isHero: Bool
    let showValue: Bool
    let layout: DailyCheckInScaleLayout

    private let maxValue = 5

    var body: some View {
        let clampedValue = max(0, min(value ?? 0, maxValue))
        let fraction = CGFloat(clampedValue) / CGFloat(maxValue)

        let labelColor = isHero ? ReflectJournalTheme.textPrimary : ReflectJournalTheme.textSecondary
        let lineHeight: CGFloat = isHero ? 8 : 6

        Group {
            if layout == .inline {
                HStack(alignment: .center, spacing: isHero ? 10 : 8) {
                    Text(label)
                        .font(.system(size: isHero ? 12 : 11, weight: .semibold))
                        .foregroundColor(labelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: 72, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(ReflectJournalTheme.progressTrack)

                            Capsule(style: .continuous)
                                .fill(ReflectJournalTheme.accent)
                                .frame(width: max(0, geo.size.width * fraction))
                        }
                    }
                    .frame(height: lineHeight)

                    if showValue {
                        Spacer(minLength: 6)
                        if value != nil {
                            Text("\(clampedValue)/\(maxValue)")
                                .font(.system(size: isHero ? 17 : 12, weight: isHero ? .bold : .semibold))
                                .foregroundColor(ReflectJournalTheme.accent)
                                .frame(minWidth: 44, alignment: .trailing)
                        } else {
                            Text("Complete")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: isHero ? 6 : 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(label)
                            .font(.system(size: isHero ? 12 : 11, weight: .semibold))
                            .foregroundColor(labelColor)

                        Spacer()

                        if showValue {
                            if value != nil {
                                Text("\(clampedValue)/\(maxValue)")
                                    .font(.system(size: isHero ? 18 : 12, weight: isHero ? .bold : .semibold))
                                    .foregroundColor(ReflectJournalTheme.accent)
                            } else {
                                Text("Complete")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(ReflectJournalTheme.textTertiary)
                            }
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(ReflectJournalTheme.progressTrack)

                            Capsule(style: .continuous)
                                .fill(ReflectJournalTheme.accent)
                                .frame(width: max(0, geo.size.width * fraction))
                        }
                    }
                    .frame(height: lineHeight)
                }
            }
        }
    }
}

private enum DailyCheckInScaleLayout {
    case stacked
    case inline
}

private struct DailyCheckInTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(ReflectJournalTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        Capsule()
                            .stroke(ReflectJournalTheme.sheetHighlight, lineWidth: 1)
                    )
            )
    }
}

private struct DailyCheckInRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(ReflectJournalTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.07 : 0.035))
            )
    }
}

private struct DailyCheckInFlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}

private func splitNotesAndSideEffects(for log: MedicationLog) -> (notes: String?, checkInNotes: String?, sideEffects: String?, mood: String?) {
    guard var raw = log.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return (nil, nil, nil, nil)
    }
    var moodValue: String?
    let lines = raw.components(separatedBy: .newlines)
    var remainingLines: [String] = []
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.lowercased().hasPrefix("mood:") {
            let value = trimmedLine.dropFirst("mood:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                moodValue = value
            }
        } else {
            remainingLines.append(line)
        }
    }
    raw = remainingLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
        sideEffectsPart?.isEmpty == true ? nil : sideEffectsPart,
        moodValue?.isEmpty == true ? nil : moodValue
    )
}

private struct DailyCheckInEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 42))
                .foregroundColor(ReflectJournalTheme.textTertiary)

            Text("No reflection entries yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textPrimary)

            Text("Your reflection notes will show up here after you log.")
                .font(.system(size: 14))
                .foregroundColor(ReflectJournalTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ReflectJournalTheme.sheetHighlight, lineWidth: 1)
                        .blendMode(.overlay)
                        .opacity(0.45)
                )
        )
    }
}

private struct DailyCheckInFilteredEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundColor(ReflectJournalTheme.textTertiary)

            Text("No reflections in this range")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textPrimary)

            Text("Try adjusting your date filter to see more entries.")
                .font(.system(size: 14))
                .foregroundColor(ReflectJournalTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ReflectJournalTheme.sheetHighlight, lineWidth: 1)
                        .blendMode(.overlay)
                        .opacity(0.45)
                )
        )
    }
}

#if DEBUG
struct DailyCheckInHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        DailyCheckInHistoryView()
            .environmentObject(MedicationStore.previewStore())
            .environmentObject(StoreManager.shared)
    }
}
#endif
