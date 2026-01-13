//
//  MedicationLogView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI
import UIKit

struct MedicationLogView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingCalendar = false
    @State private var selectedDate: Date = Date()
    @State private var selectedMedicationFilter: String = "All"
    @State private var selectedMonth: Date = Date() // Current month for calendar view
    @State private var showingExportOptions = false
    
    // Group logs by date
    private var groupedLogs: [Date: [MedicationLog]] {
        let calendar = Calendar.current
        var result = [Date: [MedicationLog]]()
        
        // Filter logs based on selected medication and exclude skipped logs
        let filteredLogs = store.logs.filter { log in
            let medicationMatch = selectedMedicationFilter == "All" || log.medicationName == selectedMedicationFilter
            return !log.skipped && medicationMatch
        }
        
        for log in filteredLogs {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.takenAt)
            if let date = calendar.date(from: dateComponents) {
                if result[date] == nil {
                    result[date] = [log]
                } else {
                    result[date]?.append(log)
                }
            }
        }
        
        // Sort logs within each day by time (most recent first)
        for (date, logs) in result {
            result[date] = logs.sorted { $0.takenAt > $1.takenAt }
        }
        
        return result
    }
    
    // Sort dates in descending order (most recent first)
    private var sortedDates: [Date] {
        return groupedLogs.keys.sorted(by: >)
    }
    
    // Filter logs for the selected date
    private var logsForSelectedDate: [MedicationLog] {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        guard let startOfDay = calendar.date(from: dateComponents) else { return [] }
        
        return groupedLogs[startOfDay] ?? []
    }
    
    // Get unique medication names for filter
    private var uniqueMedicationNames: [String] {
        let names = Set(store.logs.filter { !$0.skipped }.map { $0.medicationName })
        return ["All"] + Array(names).sorted()
    }
    
    // Date formatter for section headers
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }
    
    // Month formatter
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    // Day formatter
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    // Weekday formatter
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    // Relative date formatter for recent dates
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background color
                    Color(hex: "#404C42")
                        .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                    
                    VStack(spacing: 0) {
                        // Enhanced header with filter options
                        VStack(spacing: 12) {
                            HStack {
                                Text("Medication History")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                                
                                // Download button
                                Button(action: {
                                    shareCSV()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.doc.fill")
                                            .font(.system(size: 16))
                                        Text("Export")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "#525E55"))
                                    .cornerRadius(20)
                                }
                                
                                // Full PDF export button
                                Button(action: {
                                    shareFullHistoryPDF()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.richtext.fill")
                                            .font(.system(size: 16))
                                        Text("Full PDF")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "#C7C7BD"))
                                    .cornerRadius(20)
                                }
                                .accessibilityLabel("Export entire history as a PDF")
                                
                                // Filter button
                                Menu {
                                    Picker("Filter by Medication", selection: $selectedMedicationFilter) {
                                        ForEach(uniqueMedicationNames, id: \.self) { medicationName in
                                            Text(medicationName).tag(medicationName)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "line.3.horizontal.decrease.circle")
                                            .font(.system(size: 16))
                                        Text(selectedMedicationFilter == "All" ? "All" : selectedMedicationFilter)
                                            .font(.system(size: 14, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(20)
                                }
                            }
                            
                            // Stats row
                            GlassContainer(spacing: 20) {
                                HStack(spacing: 20) {
                                    StatCard(
                                        title: "Total Doses",
                                        value: "\(store.logs.filter { !$0.skipped }.count)",
                                        icon: "pills.fill"
                                    )
                                    
                                    StatCard(
                                        title: "This Week",
                                        value: "\(logsThisWeek)",
                                        icon: "calendar.badge.clock"
                                    )
                                    
                                    StatCard(
                                        title: "Streak",
                                        value: "\(currentStreak) days",
                                        icon: "flame.fill"
                                    )
                                }
                            }
                            
                            if let trendsText = focusTrendsSummary {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "hourglass")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        Text("Focus & side-effect trends")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                    }
                                    
                                    Text(trendsText)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.black.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color(hex: "#C7C7BD").opacity(0.25), lineWidth: 1)
                                        )
                                )
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .background(Color(hex: "#404C42"))
                        .zIndex(1)
                        
                        // Month navigation and calendar view
                        VStack(spacing: 12) {
                            // Month navigation
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                }
                                
                                Spacer()
                                
                                Text(monthFormatter.string(from: selectedMonth))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Calendar header (days of week)
                            HStack(spacing: 0) {
                                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                                    Text(day.prefix(1))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            
                            // Calendar grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                                ForEach(daysInMonth(), id: \.self) { day in
                                    CalendarDayCell(
                                        date: day,
                                        selectedDate: $selectedDate,
                                        groupedLogs: groupedLogs,
                                        isCurrentMonth: isSameMonth(day, selectedMonth)
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 16)
                            
                            // Current selection indicator if not today
                            if !Calendar.current.isDateInToday(selectedDate) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    
                                    Text(dateFormatter.string(from: selectedDate))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassRectBackground(cornerRadius: 8, opacity: 0.9)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.bottom, 8)
                        .background(Color(hex: "#404C42"))
                        
                        // Content area
                        ZStack {
                            if store.logs.filter({ !$0.skipped }).isEmpty {
                                EmptyHistoryView()
                            } else if logsForSelectedDate.isEmpty && !Calendar.current.isDateInToday(selectedDate) {
                                NoLogsForDateView(date: selectedDate, dateFormatter: dateFormatter)
                            } else {
                                LogsContentView(
                                    selectedDate: selectedDate,
                                    sortedDates: sortedDates,
                                    groupedLogs: groupedLogs,
                                    logsForSelectedDate: logsForSelectedDate,
                                    store: store
                                )
                            }
                        }
                        .navigationBarHidden(true)
                    }
                    .padding(.horizontal, horizontalInsets(for: geometry))
                    
                    // Floating buttons
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 12) {
                                // Export button
                                FloatingButton(
                                    icon: "arrow.down.doc.fill",
                                    action: { shareCSV() }
                                )
                                
                                // Today button (only show if not on today)
                                if !Calendar.current.isDateInToday(selectedDate) {
                                    FloatingButton(
                                        icon: "house.fill",
                                        action: {
                                            selectedDate = Date()
                                            selectedMonth = Date()
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 50)
                    }
                    .zIndex(2)
                }
            }
        }
        .background(Color.clear)
        .navigationViewStyle(.stack)
    }
    
    
    // Calculate logs this week
    private var logsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return store.logs.filter { log in
            !log.skipped && log.takenAt >= weekAgo && log.takenAt <= now
        }.count
    }
    
    // Calculate current streak
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        while true {
            let hasLogForDate = store.logs.contains { log in
                !log.skipped && calendar.isDate(log.takenAt, inSameDayAs: currentDate)
            }
            
            if hasLogForDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    // Simple aggregated trends for ADHD-focused check-ins
    private var focusTrendsSummary: String? {
        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return nil }
        
        // Map medication ID -> Medication for quick lookup
        let medsByID = Dictionary(uniqueKeysWithValues: store.medications.map { ($0.id, $0) })
        
        // Only consider logs in last 30 days with ratings
        let recentLogs = store.logs.filter { log in
            log.takenAt >= thirtyDaysAgo &&
            log.takenAt <= now &&
            !log.skipped &&
            (log.feelingRating != nil || log.focusRating != nil || log.sideEffectSeverity != nil)
        }
        
        guard !recentLogs.isEmpty else { return nil }
        
        struct Agg {
            var focusTotal = 0
            var focusCount = 0
            var sideTotal = 0
            var sideCount = 0
        }
        
        var aggByMed: [UUID: Agg] = [:]
        
        for log in recentLogs {
            guard let med = medsByID[log.medicationID],
                  med.medicationType == .stimulant else { continue }
            
            var agg = aggByMed[log.medicationID] ?? Agg()
            if let f = log.focusRating {
                agg.focusTotal += f
                agg.focusCount += 1
            }
            if let s = log.sideEffectSeverity {
                agg.sideTotal += s
                agg.sideCount += 1
            }
            aggByMed[log.medicationID] = agg
        }
        
        guard !aggByMed.isEmpty else { return nil }
        
        // Build short summary for at most top 2 meds with most focus ratings
        let sorted = aggByMed.sorted { lhs, rhs in
            lhs.value.focusCount > rhs.value.focusCount
        }
        
        var parts: [String] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        for (index, entry) in sorted.enumerated() {
            if index >= 2 { break }
            guard let med = medsByID[entry.key] else { continue }
            let agg = entry.value
            
            let focusText: String
            if agg.focusCount > 0 {
                let avgFocus = Double(agg.focusTotal) / Double(max(1, agg.focusCount))
                focusText = String(format: "average focus ~%.1f/5 over %d check-ins", avgFocus, agg.focusCount)
            } else {
                focusText = "no focus ratings yet"
            }
            
            let sideText: String
            if agg.sideCount > 0 {
                let avgSide = Double(agg.sideTotal) / Double(max(1, agg.sideCount))
                sideText = String(format: "side effects ~%.1f/5", avgSide)
            } else {
                sideText = "no side-effect ratings yet"
            }
            
            parts.append("\(med.name): \(focusText), \(sideText).")
        }
        
        guard !parts.isEmpty else { return nil }
        
        return parts.joined(separator: " ")
    }
    
    // Check if date is recent (within last week)
    private func isDateRecent(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return date >= weekAgo
    }
    
    // Calculate proper insets based on screen size
    private func horizontalInsets(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            return max((geometry.size.width - 768) / 3, 0)
        }
        return 0
    }
    
    // Get days in the current month for the calendar
    private func daysInMonth() -> [Date] {
        let calendar = Calendar.current
        
        // Find the first day of the month
        let monthComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
        let startOfMonth = calendar.date(from: monthComponents)!
        
        // Find the start of the first week (may be in the previous month)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysToSubtract = (firstWeekday - calendar.firstWeekday + 7) % 7
        let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfMonth)!
        
        // Generate the days needed for a complete calendar (up to 42 days)
        var dates: [Date] = []
        for day in 0..<42 { // 6 weeks (rows) * 7 days
            if let date = calendar.date(byAdding: .day, value: day, to: startDate) {
                dates.append(date)
                
                // Stop if we've reached the end of the month and completed the row
                let endOfMonthCheck = calendar.dateComponents([.month], from: date)
                let nextMonth = calendar.dateComponents([.month], from: selectedMonth).month! + 1
                if endOfMonthCheck.month == nextMonth && calendar.component(.weekday, from: date) == calendar.firstWeekday {
                    break
                }
            }
        }
        
        return dates
    }
    
    // Check if a date is in the current month being displayed
    private func isSameMonth(_ date: Date, _ monthDate: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.month, from: date) == calendar.component(.month, from: monthDate) &&
        calendar.component(.year, from: date) == calendar.component(.year, from: monthDate)
    }
    
    // MARK: - Export Functionality
    // Function to export medication logs as CSV
    private func exportMedicationLogsAsCSV() -> String {
        // CSV header
        var csvString = "Date,Time,Medication,Dosage,Notes,Skipped\n"
        
        // Date formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        // Add data rows
        let filteredLogs = store.logs.filter { log in
            selectedMedicationFilter == "All" || log.medicationName == selectedMedicationFilter
        }
        
        for log in filteredLogs.sorted(by: { $0.takenAt > $1.takenAt }) {
            let date = dateFormatter.string(from: log.takenAt)
            let time = timeFormatter.string(from: log.takenAt)
            let medicationName = log.medicationName
            
            // Use the stored dose text to avoid retroactive updates
            let dosage = log.recordedDosageWithUnit
            
            // Clean up notes to be CSV compatible
            let cleanNotes = log.notes?.replacingOccurrences(of: ",", with: ";") ?? ""
            let cleanMedicationName = medicationName.replacingOccurrences(of: ",", with: ";")
            
            // Add row
            csvString += "\(date),\(time),\"\(cleanMedicationName)\",\"\(dosage)\",\"\(cleanNotes)\",\(log.skipped ? "Yes" : "No")\n"
        }
        
        return csvString
    }
    
    // Function to create and share the CSV file
    private func shareCSV() {
        let csvString = exportMedicationLogsAsCSV()
        
        // Create a temporary file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "MedicationHistory_\(dateFormatter.string(from: Date())).csv"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            
            do {
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                presentShareSheet(with: fileURL)
            } catch {
                print("Error writing CSV file: \(error)")
            }
        }
    }
    
    private func shareFullHistoryPDF() {
        guard let pdfURL = generateFullHistoryPDF() else { return }
        presentShareSheet(with: pdfURL)
    }
    
    private func generateFullHistoryPDF() -> URL? {
        let logs = store.logs.sorted(by: { $0.takenAt > $1.takenAt })
        guard !logs.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let groupedLogs = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.takenAt) }
        let sortedDates = groupedLogs.keys.sorted(by: >)
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
                
                for log in (groupedLogs[date] ?? []).sorted(by: { $0.takenAt > $1.takenAt }) {
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
    
    private func presentShareSheet(with fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let popoverController = activityVC.popoverPresentationController,
           let rootView = UIApplication.shared.windows.first?.rootViewController?.view {
            popoverController.sourceView = rootView
            popoverController.sourceRect = CGRect(x: rootView.bounds.midX, y: rootView.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var presentingController = rootViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            presentingController.present(activityVC, animated: true, completion: nil)
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
} // <-- Added closing brace for var body here


// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let groupedLogs: [Date: [MedicationLog]]
    let isCurrentMonth: Bool
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var hasLogs: Bool {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard let startOfDay = calendar.date(from: dateComponents) else { return false }
        
        return groupedLogs[startOfDay] != nil
    }
    
    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: {
            withAnimation {
                selectedDate = date
            }
        }) {
            VStack(spacing: 2) {
                // Day number
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundColor(
                        isToday ? Color(hex: "#F5F5F5") :
                            isSelected ? Color(hex: "#F5F5F5") :
                            isCurrentMonth ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.4)
                    )
                
                // Indicator dot for days with logs
                if hasLogs {
                    Circle()
                        .fill(
                            isSelected ? Color(hex: "#F5F5F5") :
                                isToday ? Color(hex: "#D7CCC8") : Color(hex: "#D7CCC8").opacity(0.8)
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#525E55"))
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        Circle()
                            .stroke(Color(hex: "#D7CCC8"), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#525E55"))
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#525E55"))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "#525E55").opacity(0.6))
                    .padding(.bottom, 10)
                
                Text("No medication history yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#525E55"))
                
                Text("Start logging your medications to see your history here. Your medication adherence journey begins with the first dose!")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#525E55").opacity(0.8))
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .glassRectBackground(cornerRadius: 20, opacity: 1)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
            .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 16)
            .padding(.top, 40)
        }
    }
}

struct NoLogsForDateView: View {
    let date: Date
    let dateFormatter: DateFormatter
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "#525E55").opacity(0.6))
                    .padding(.bottom, 10)
                
                Text("No medications taken")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#525E55"))
                
                Text("No medications were logged on \(dateFormatter.string(from: date))")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .glassRectBackground(cornerRadius: 20, opacity: 1)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
            .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

struct LogsContentView: View {
    let selectedDate: Date
    let sortedDates: [Date]
    let groupedLogs: [Date: [MedicationLog]]
    let logsForSelectedDate: [MedicationLog]
    let store: MedicationStore
    
    var body: some View {
        if Calendar.current.isDateInToday(selectedDate) {
            // Show all logs grouped by date
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    ForEach(sortedDates, id: \.self) { date in
                        Section {
                            VStack(spacing: 12) {
                                ForEach(groupedLogs[date] ?? []) { logEntry in
                                    EnhancedLogEntryRow(logEntry: logEntry)
                                }
                            }
                        } header: {
                            DateSectionHeader(date: date)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        } else {
            // Show only logs for selected date
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(logsForSelectedDate) { logEntry in
                        EnhancedLogEntryRow(logEntry: logEntry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

struct DateSectionHeader: View {
    let date: Date
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    var body: some View {
        HStack {
            Text(dateFormatter.string(from: date))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Spacer()
            
            // Day of week
            Text(dayOfWeekFormatter.string(from: date))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(hex: "#404C42"))
    }
    
    private var dayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }
    
    private func isDateRecent(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return date >= weekAgo
    }
}

struct EnhancedLogEntryRow: View {
    let logEntry: MedicationLog
    @State private var showAdditionalInfo: Bool = false

    private var resolvedIconName: String {
        logEntry.recordedIconName.isEmpty ? "pill.fill" : logEntry.recordedIconName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main medication info
            HStack(alignment: .top, spacing: 12) {
                // Medication icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#525E55").opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: resolvedIconName)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#525E55"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Medication name and dosage
                    HStack {
                        Text(logEntry.medicationName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#525E55"))

                        Spacer()

                        // Time taken
                        Text(timeFormatter.string(from: logEntry.takenAt))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#525E55").opacity(0.8))
                    }

                    // Dosage information
                    if !logEntry.recordedDosageWithUnit.isEmpty {
                        HStack(spacing: 8) {
                            Text(logEntry.recordedDosageWithUnit)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#525E55"))

                            if let pillsConsumed = logEntry.pillsConsumed, pillsConsumed > 1 {
                                Text("• \(pillsConsumed) pills")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                            }

                            Spacer()
                        }
                    }

                    // Show toggle button if notes exist
                    if let notes = logEntry.notes, !notes.isEmpty {
                        Button(action: {
                            withAnimation {
                                showAdditionalInfo.toggle()
                            }
                        }) {
                            HStack {
                                Text("Additional Information")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#525E55").opacity(0.8))

                                Spacer()

                                Image(systemName: showAdditionalInfo ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#525E55").opacity(0.5))
                            }
                            .padding(.top, 6)
                        }

                        // Notes and side effects (collapsible)
                        if showAdditionalInfo {
                            VStack(alignment: .leading, spacing: 6) {
                                if notes.contains("Side effects:") {
                                    let components = notes.components(separatedBy: "Side effects:")

                                    // Regular notes
                                    if components.count > 0 && !components[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(components[0].trimmingCharacters(in: .whitespacesAndNewlines))
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "#525E55").opacity(0.8))
                                    }

                                    // Side effects
                                    if components.count > 1 {
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.orange)

                                            Text("Side effects: \(components[1].trimmingCharacters(in: .whitespacesAndNewlines))")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "note.text.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#525E55").opacity(0.6))

                                        Text(notes)
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "#525E55").opacity(0.8))
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

struct FloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.white)
                .frame(width: 50, height: 50)
                .glassCircleBackground(diameter: 50, opacity: 0.98)
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(hapticStyle: .pulseButton))
    }
}

struct DatePickerOverlay: View {
    @Binding var selectedDate: Date
    @Binding var showingCalendar: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingCalendar = false
                }
            
            VStack(spacing: 16) {
                HStack {
                    Text("Select Date")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Spacer()
                    
                    Button(action: {
                        showingCalendar = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 12)
                
                HStack(spacing: 12) {
                    Button("Today") {
                        selectedDate = Date()
                        showingCalendar = false
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    Button("Select") {
                        showingCalendar = false
                    }
                    .foregroundColor(Color(hex: "#404C42"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color(hex: "#C7C7BD"))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .glassRectBackground(cornerRadius: 16, opacity: 0.95)
            .frame(width: min(geometry.size.width - 40, 400))
            .padding(.horizontal, 20)
        }
    }
}
