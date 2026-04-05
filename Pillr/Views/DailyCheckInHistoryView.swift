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
    static let pageTop = Color.pillrPrimary
    static let pageBottom = Color.pillrPrimary

    static let textPrimary = Color.pillrBackground
    static let textSecondary = Color.pillrSecondary.opacity(0.9)
    static let textTertiary = Color.pillrSecondary.opacity(0.7)

    // Paper
    static let sheetFill = Color.white.opacity(0.04)
    static let sheetFillExpanded = Color.white.opacity(0.04)
    static let sheetHighlight = Color.white.opacity(0.06)

    // Accents
    static let accent = Color.pillrAccent
    static let reflectionScoreAccent = Color(hex: "#B8E6B8")
    static let sideEffectAccent = Color(hex: "#F4C4B3")
    static let progressTrack = Color.white.opacity(0.16)

    static var pageBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [pageTop, pageBottom]),
            startPoint: .top,
            endPoint: .bottom
        )
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
                            .stroke(ReflectJournalTheme.sheetHighlight, lineWidth: 1)
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

private struct ReflectionActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textPrimary)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ReflectJournalTheme.sheetFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ReflectJournalTheme.sheetHighlight.opacity(0.6), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
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

    private var lastSevenDaysStart: Date {
        Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    }

    private var lastSevenDaysCheckIns: [MedicationLog] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: lastSevenDaysStart)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()

        return checkInLogs.filter {
            $0.takenAt >= start && $0.takenAt <= end
        }
    }

    private var medicationAverages: [(medicationName: String, average: Double, count: Int)] {
        let logs = lastSevenDaysCheckIns.compactMap { log -> (String, Int)? in
            guard let feeling = log.feelingRating, feeling > 0 else { return nil }
            let name = log.medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
            let medicationName = name.isEmpty ? "Medication" : name
            return (medicationName, feeling)
        }

        let grouped = Dictionary(grouping: logs, by: { $0.0 })
        return grouped.keys.sorted { lhs, rhs in
            let lhsAverage = grouped[lhs]?.map(\.1).reduce(0, +) ?? 0
            let lhsCount = grouped[lhs]?.count ?? 1
            let rhsAverage = grouped[rhs]?.map(\.1).reduce(0, +) ?? 0
            let rhsCount = grouped[rhs]?.count ?? 1

            let lhsValue = Double(lhsAverage) / Double(lhsCount)
            let rhsValue = Double(rhsAverage) / Double(rhsCount)
            if lhsValue == rhsValue {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            return lhsValue > rhsValue
        }.map { name in
            let values = grouped[name] ?? []
            let total = values.map(\.1).reduce(0, +)
            let count = values.count
            return (name, Double(total) / Double(count), count)
        }
    }

    private var overallLastSevenDaysAverage: Double? {
        let values = lastSevenDaysCheckIns.compactMap { $0.feelingRating }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private var thisWeekCheckIns: [MedicationLog] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        return checkInLogs.filter { $0.takenAt >= start && $0.takenAt <= end }
    }

    private var previousWeekCheckIns: [MedicationLog] {
        let calendar = Calendar.current
        let now = Date()
        let end = calendar.startOfDay(for: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now)
        let start = calendar.startOfDay(for: Calendar.current.date(byAdding: .day, value: -13, to: now) ?? now)
        let rangeEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return checkInLogs.filter { $0.takenAt >= start && $0.takenAt <= rangeEnd }
    }

    private var trendText: String {
        let thisWeekValues = thisWeekCheckIns.compactMap { $0.feelingRating }.filter { $0 > 0 }
        let previousWeekValues = previousWeekCheckIns.compactMap { $0.feelingRating }.filter { $0 > 0 }

        guard !thisWeekValues.isEmpty, !previousWeekValues.isEmpty else {
            return "+0.0/5"
        }

        let thisWeekAverage = Double(thisWeekValues.reduce(0, +)) / Double(thisWeekValues.count)
        let previousWeekAverage = Double(previousWeekValues.reduce(0, +)) / Double(previousWeekValues.count)
        let difference = thisWeekAverage - previousWeekAverage
        let formatted = String(format: "%.1f", abs(difference))

        if difference > 0 {
            return "+\(formatted)/5"
        } else if difference < 0 {
            return "-\(formatted)/5"
        } else {
            return "0.0/5"
        }
    }

    private var lastSevenDaysLoggedDays: Int {
        let calendar = Calendar.current
        let days = Set(lastSevenDaysCheckIns.compactMap { log -> Date? in
            guard let feeling = log.feelingRating, feeling > 0 else { return nil }
            return calendar.startOfDay(for: log.takenAt)
        })
        return days.count
    }

    private var lastSevenDaysStreak: Int {
        let calendar = Calendar.current
        let loggedDays = Set(lastSevenDaysCheckIns.compactMap { log -> Date? in
            guard let feeling = log.feelingRating, feeling > 0 else { return nil }
            return calendar.startOfDay(for: log.takenAt)
        })

        guard !loggedDays.isEmpty else { return 0 }

        var currentDay = calendar.startOfDay(for: Date())
        if !loggedDays.contains(currentDay) {
            guard let mostRecent = loggedDays.max() else { return 0 }
            currentDay = mostRecent
        }

        var streak = 0
        while loggedDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = previousDay
        }

        return streak
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

    var body: some View {
        NavigationView {
            ZStack {
                ReflectJournalTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if isPremiumActive {
                            headerSection
                            statsSection
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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
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
                        .foregroundColor(Color.pillrBackground)
                    Text("This reflection entry can't be edited right now.")
                        .font(.system(size: 14))
                        .foregroundColor(Color.pillrSecondary)
                }
                .padding(24)
                .background(Color.pillrPrimary.ignoresSafeArea())
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
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reflection")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(ReflectJournalTheme.textPrimary)

                Text(headerSummaryText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(ReflectJournalTheme.textSecondary)

                if hasCustomDateFilter {
                    Text(dateRangeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textSecondary)
                        .padding(.top, 6)
                }
            }

            Spacer()

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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textPrimary)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .frame(width: 46, height: 46)
            .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
            .contentShape(Circle())
            .disabled(checkInLogs.isEmpty && isPremiumActive)
            .accessibilityLabel("Export reflections")
            .onTapGesture {
                if !isPremiumActive {
                    showingPremiumUpgrade = true
                }
            }

            Button {
                if isPremiumActive {
                    showingDateRangeSheet = true
                } else {
                    showingPremiumUpgrade = true
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textPrimary)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .frame(width: 46, height: 46)
            .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
            .contentShape(Circle())
            .disabled(checkInLogs.isEmpty && isPremiumActive)
            .accessibilityLabel(hasCustomDateFilter ? "Filtered date range" : "Filter date range")

            Button(action: {
                if isPremiumActive {
                    showingQuickCheckIn = true
                } else {
                    showingPremiumUpgrade = true
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textPrimary)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .frame(width: 46, height: 46)
            .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
            .contentShape(Circle())
            .disabled(defaultMedicationForCheckIn == nil && isPremiumActive)
        }
        .padding(.top, 12)
    }

    private var headerSummaryText: String {
        "\(filteredCheckInLogs.count) \(filteredCheckInLogs.count == 1 ? "entry" : "entries") logged"
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(historyDashboardCardBackground)
                .zIndex(1)

            VStack(spacing: 0) {
                medicationSummaryList
            }
            .padding(.horizontal, 16)
            .padding(.top, 30)
            .padding(.bottom, 40)
            .background(historyConnectedControlsBackground)
            .padding(.top, -18)
        }
        .padding(.top, 0)
        .padding(.bottom, 6)
    }

    private var historyDashboardCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(hex: "#59655B"))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hex: "#8C988E").opacity(0.75), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
    }

    private var historyConnectedControlsBackground: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color(hex: "#424C43"))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(Color(hex: "#8C988E").opacity(0.75), lineWidth: 1)
            )

            Rectangle()
                .fill(Color(hex: "#59655B"))
                .frame(height: 6)
                .opacity(0.95)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 7 days")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.pillrSecondary.opacity(0.7))
                .kerning(0.45)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Avg Overall")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.pillrSecondary.opacity(0.7))
                        .kerning(0.45)
                        .frame(height: 16, alignment: .topLeading)

                    Text(overallLastSevenDaysAverage.map { String(format: "%.1f/5", $0) } ?? "—")
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .foregroundColor(ReflectJournalTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .overlay(Color.white.opacity(0.16))
                    .frame(width: 1, height: 86)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trend")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.pillrSecondary.opacity(0.7))
                        .kerning(0.45)
                        .frame(height: 16, alignment: .topLeading)

                    Text(trendText)
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .foregroundColor(ReflectJournalTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: "#59655B"))
        )
    }

    private var medicationSummaryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(medicationAverages.enumerated()), id: \.element.medicationName) { index, item in
                medicationAverageRow(
                    medicationName: item.medicationName,
                    average: item.average,
                    count: item.count
                )

                if index != medicationAverages.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.12))
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func medicationAverageRow(medicationName: String, average: Double, count: Int) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(medicationName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f/5", average))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(ReflectJournalTheme.reflectionScoreAccent)

                Text("\(count) \(count == 1 ? "entry" : "entries")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ReflectJournalTheme.textSecondary.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reflectionInfoCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Premium feature")
                    .journalSectionHeader()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reflection")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textPrimary)

                    Text("See how your medication affects mood, focus, and side effects over time.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(ReflectJournalTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                reflectionFeaturePill(text: "AI summaries", icon: "sparkles")
                reflectionFeaturePill(text: "History view", icon: "clock.arrow.circlepath")
                reflectionFeaturePill(text: "PDF export", icon: "doc.richtext")
            }

            reflectionPreviewCard

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    showingPremiumUpgrade = true
                } label: {
                    HStack(spacing: 10) {
                        Text("Unlock Reflection")
                            .font(.system(size: 16, weight: .semibold))

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color.pillrPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.pillrBackground)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock Reflection")

                Text("One purchase unlocks Reflection, export, and smart summaries.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ReflectJournalTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reflectionFeaturePill(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))

            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(ReflectJournalTheme.textPrimary.opacity(0.92))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private var reflectionPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Example reflection")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer(minLength: 0)
            }

            Image("Reflection Example")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedCheckIns, id: \.date) { date, logs in
                VStack(alignment: .leading, spacing: 12) {
                    dayHeader(for: date)

                    VStack(spacing: 16) {
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
        .padding(.top, 38)
    }

    private func dayHeader(for date: Date) -> some View {
        HStack(spacing: 12) {
            Text(dayLabel(for: date))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ReflectJournalTheme.textPrimary)
                .fixedSize(horizontal: true, vertical: false)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            Text(dayHeaderRightLabel(for: date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ReflectJournalTheme.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
        }
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

    private func dayHeaderRightLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return DailyCheckInHistoryView.dayFormatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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

        var csv = "Date,Time,Medication,Overall feeling,Focus level,Side-effect impact,Mood overall,Notes,Side effects picked\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        for log in logs {
            let noteParts = splitNotesAndSideEffects(for: log)
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
        let cardTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let cardBodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let cardLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .bold),
            .foregroundColor: UIColor.darkGray
        ]
        let cardValueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let cardFill = UIColor.white.withAlphaComponent(0.88)
        let cardStroke = UIColor.black.withAlphaComponent(0.08)
        let cardPadding: CGFloat = 14
        let cardSpacing: CGFloat = 14
        let sectionGap: CGFloat = 12

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

            func drawCardBackground(height: CGFloat) {
                let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 16)
                cardFill.setFill()
                path.fill()
                cardStroke.setStroke()
                path.lineWidth = 1
                path.stroke()
            }

            func drawReflectionCard(for log: MedicationLog) {
                let noteParts = splitNotesAndSideEffects(for: log)
                var lines: [(NSAttributedString, CGFloat)] = []
                lines.append((NSAttributedString(string: dateFormatter.string(from: log.takenAt), attributes: cardTitleAttributes), 4))
                lines.append((NSAttributedString(string: "\(timeFormatter.string(from: log.takenAt)) • \(log.medicationName)", attributes: cardBodyAttributes), 6))

                let ratingsText = "Overall feeling: \(ratingDisplay(log.feelingRating))   Focus level: \(ratingDisplay(log.focusRating))   Side-effect impact: \(ratingDisplay(log.sideEffectSeverity))"
                lines.append((NSAttributedString(string: ratingsText, attributes: cardBodyAttributes), sectionGap))

                if let mood = noteParts.mood?.trimmingCharacters(in: .whitespacesAndNewlines), !mood.isEmpty {
                    lines.append((NSAttributedString(string: "Mood overall", attributes: cardLabelAttributes), 4))
                    lines.append((NSAttributedString(string: mood, attributes: cardValueAttributes), sectionGap))
                }
                if let checkInNotes = noteParts.checkInNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !checkInNotes.isEmpty {
                    lines.append((NSAttributedString(string: "Notes", attributes: cardLabelAttributes), 4))
                    lines.append((NSAttributedString(string: checkInNotes, attributes: cardValueAttributes), sectionGap))
                }
                if let sideEffects = noteParts.sideEffects?.trimmingCharacters(in: .whitespacesAndNewlines), !sideEffects.isEmpty {
                    lines.append((NSAttributedString(string: "Side effects picked", attributes: cardLabelAttributes), 4))
                    lines.append((NSAttributedString(string: sideEffects, attributes: cardValueAttributes), 0))
                }

                let usableWidth = contentWidth - (cardPadding * 2)
                let cardHeight = lines.reduce(CGFloat(0)) { total, line in
                    total + height(for: line.0, width: usableWidth) + line.1
                } + cardPadding * 2 + 4

                if currentY + cardHeight > pageRect.height - margin {
                    beginPage()
                }

                drawCardBackground(height: cardHeight)

                var yCursor = currentY + cardPadding
                for (index, line) in lines.enumerated() {
                    let lineHeight = height(for: line.0, width: usableWidth)
                    line.0.draw(in: CGRect(x: margin + cardPadding, y: yCursor, width: usableWidth, height: lineHeight))
                    yCursor += lineHeight + line.1
                    if index == 0 {
                        yCursor += 2
                    }
                }

                currentY += cardHeight + cardSpacing
            }

            beginPage()
            drawText(NSAttributedString(string: "Reflection Notes Export", attributes: titleAttributes), spacingAfter: 4)
            let exportedOn = "Exported on \(exportedOnFormatter.string(from: Date()))"
            drawText(NSAttributedString(string: exportedOn, attributes: subtitleAttributes), spacingAfter: 12)

            for date in sortedDates {
                let entries = (grouped[date] ?? []).sorted(by: { $0.takenAt > $1.takenAt })
                for log in entries {
                    drawReflectionCard(for: log)
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
    @State private var showingActionMenu = false
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

    private var actionButtonTextColor: Color {
        ReflectJournalTheme.textPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                if isExpanded {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(medicationName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textPrimary)

                            Text(timeText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ReflectJournalTheme.textSecondary)
                        }

                        Spacer()
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
                                .foregroundColor(ReflectJournalTheme.textPrimary)

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
                                .foregroundColor(ReflectJournalTheme.textPrimary)

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
                                .foregroundColor(ReflectJournalTheme.textPrimary)

                            DailyCheckInFlowLayout(spacing: 6) {
                                ForEach(sideEffectChips, id: \.self) { effect in
                                    DailyCheckInTag(text: effect)
                                }
                            }
                        }
                    }

                    if showingActionMenu {
                        VStack(spacing: 8) {
                            Button {
                                onEdit()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Edit")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer(minLength: 0)
                                }
                                .foregroundColor(actionButtonTextColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                showingDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Delete")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer(minLength: 0)
                                }
                .foregroundColor(.red.opacity(0.95))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#4A4A45"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.22), lineWidth: 1)
                        )
                )
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                showingActionMenu.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
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

    private var accentColor: Color {
        label.localizedCaseInsensitiveContains("side") ? ReflectJournalTheme.sideEffectAccent : ReflectJournalTheme.reflectionScoreAccent
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
                    .foregroundColor(accentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(ReflectJournalTheme.progressTrack)

                    Capsule(style: .continuous)
                        .fill(accentColor)
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

    private var accentColor: Color {
        label.localizedCaseInsensitiveContains("side") ? ReflectJournalTheme.sideEffectAccent : ReflectJournalTheme.reflectionScoreAccent
    }

    var body: some View {
        let clampedValue = max(0, min(value ?? 0, maxValue))
        let fraction = CGFloat(clampedValue) / CGFloat(maxValue)

        let labelColor = ReflectJournalTheme.textPrimary
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
                                .fill(accentColor)
                                .frame(width: max(0, geo.size.width * fraction))
                        }
                    }
                    .frame(height: lineHeight)

                    if showValue {
                        Spacer(minLength: 6)
                        if value != nil {
                            Text("\(clampedValue)/\(maxValue)")
                                .font(.system(size: isHero ? 17 : 12, weight: isHero ? .bold : .semibold))
                                .foregroundColor(accentColor)
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
                                    .foregroundColor(accentColor)
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
                                .fill(accentColor)
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
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
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

private struct HistorySummaryItem: View {
    let label: String
    let value: String
    var valueColor: Color = Color.pillrBackground
    var valueFontSize: CGFloat = 24
    var labelFontSize: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: labelFontSize, weight: .semibold))
                .foregroundColor(Color.pillrSecondary.opacity(0.7))
                .kerning(0.45)

            Text(value)
                .font(.system(size: valueFontSize, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
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
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing, alignment: .leading),
                GridItem(.flexible(), spacing: spacing, alignment: .leading)
            ],
            alignment: .leading,
            spacing: spacing
        ) {
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
struct DailyCheckInHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        DailyCheckInHistoryView()
            .environmentObject(MedicationStore.previewStore())
            .environmentObject(StoreManager.shared)
    }
}
#endif
