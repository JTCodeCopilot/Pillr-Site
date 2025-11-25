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
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }()
    
    init(isModal: Bool = false) {
        self.isModal = isModal
    }
    
    private var medicationFilters: [String] {
        let names = Set(store.logs.map { $0.medicationName })
        return ["All"] + names.sorted()
    }
    
    private var filteredLogs: [MedicationLog] {
        store.logs.filter { log in
            let matchesMedication = selectedMedication == "All" || log.medicationName == selectedMedication
            let matchesSkipFilter = includeSkipped || !log.skipped
            return matchesMedication && matchesSkipFilter
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
    
    private var takenCount: Int {
        store.logs.filter { !$0.skipped }.count
    }
    
    private var adherenceRate: String {
        let total = store.logs.count
        guard total > 0 else { return "—" }
        let rate = Int((Double(takenCount) / Double(total)) * 100)
        return "\(rate)%"
    }
    
    private var lastSevenDays: Int {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return store.logs.filter { $0.takenAt >= start && !$0.skipped }.count
    }
    
    private var notesCount: Int {
        store.logs.filter { ($0.notes?.isEmpty == false) }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#3D463F"),
                        Color(hex: "#2E352F")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        filtersSection
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
            .navigationTitle("History")
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
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("History")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text("Review your past doses, notes, and streaks in one place.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
        }
    }
    
    private var filtersSection: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(medicationFilters, id: \.self) { name in
                    Button {
                        selectedMedication = name
                    } label: {
                        Label(name, systemImage: name == selectedMedication ? "checkmark" : "pills")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                    Text(selectedMedication)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.8)
                }
                .foregroundColor(Color(hex: "#404C42"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: "#D7CCC8"))
                .cornerRadius(12)
            }
            
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    includeSkipped.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: includeSkipped ? "checkmark.circle.fill" : "slash.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(includeSkipped ? "Include skipped" : "Hide skipped")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#C7C7BD"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    private var statsSection: some View {
        GlassContainer(spacing: 14) {
            HStack(spacing: 14) {
                HistoryStatCard(
                    title: "Logged doses",
                    value: "\(takenCount)",
                    detail: adherenceRate == "—" ? "Start logging to track adherence" : "Adherence \(adherenceRate)"
                )
                
                HistoryStatCard(
                    title: "Last 7 days",
                    value: "\(lastSevenDays)",
                    detail: "Completed doses"
                )
                
                HistoryStatCard(
                    title: "Saved notes",
                    value: "\(notesCount)",
                    detail: "With side effects or focus"
                )
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedLogs, id: \.date) { date, logs in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(dayLabel(for: date))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                            MedicationTimelineRow(
                                log: log,
                                medication: medication(for: log),
                                timeText: MedicationHistoryView.timeFormatter.string(from: log.takenAt),
                                isLast: index == logs.count - 1
                            )
                        }
                    }
                }
            }
        }
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
    
    private func medication(for log: MedicationLog) -> Medication? {
        store.medications.first { $0.id == log.medicationID }
    }
}

private struct MedicationTimelineRow: View {
    let log: MedicationLog
    let medication: Medication?
    let timeText: String
    let isLast: Bool
    
    private var iconName: String {
        medication?.iconName ?? "pills.fill"
    }
    
    private var dosageText: String? {
        guard let medication else { return nil }
        let dose = medication.dosage.isEmpty ? nil : medication.dosage
        return dose
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Circle()
                    .fill(log.skipped ? Color(hex: "#C62828") : Color(hex: "#D7CCC8"))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 8) {
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#D7CCC8"))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.medicationName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            if let dosageText {
                                Text(dosageText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(timeText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                }
                
                HStack(spacing: 8) {
                    HistoryChip(
                        icon: log.skipped ? "xmark.circle.fill" : "checkmark.circle.fill",
                        text: log.skipped ? "Skipped" : "Taken",
                        tint: log.skipped ? Color(hex: "#F28B82") : Color(hex: "#C7C7BD")
                    )
                    
                    if let pills = log.pillsConsumed {
                        HistoryChip(
                            icon: "capsule.fill",
                            text: pills == 1 ? "1 pill" : "\(pills) pills",
                            tint: Color(hex: "#C7C7BD").opacity(0.9)
                        )
                    }
                    
                    if let reminder = log.reminderIndex {
                        HistoryChip(
                            icon: "bell.badge.fill",
                            text: "Reminder \(reminder + 1)",
                            tint: Color(hex: "#C7C7BD").opacity(0.9)
                        )
                    }
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
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
    }
}

private struct HistoryChip: View {
    let icon: String
    let text: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(Color(hex: "#404C42"))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
            let med = medication(for: log)
            let dosage = [med?.dosage, med?.dosageUnit].compactMap { $0 }.joined(separator: " ")
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
        let medicationsByID = Dictionary(uniqueKeysWithValues: store.medications.map { ($0.id, $0) })
        
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
                let medication = medicationsByID[log.medicationID]
                let dosageText: String
                if let med = medication {
                    dosageText = "\(med.dosage) \(med.dosageUnit)"
                } else {
                    dosageText = ""
                }
                
                let timeString = timeFormatter.string(from: log.takenAt)
                var lines: [String] = []
                if dosageText.isEmpty {
                    lines.append("\(timeString) – \(log.medicationName)")
                } else {
                    lines.append("\(timeString) – \(log.medicationName) (\(dosageText))")
                }
                
                var statusLine = "Status: " + (log.skipped ? "Skipped" : "Taken")
                if let pills = log.pillsConsumed, pills > 0 {
                    statusLine += " · \(pills) pill\(pills == 1 ? "" : "s")"
                }
                if let reminder = log.reminderIndex {
                    statusLine += " · Reminder \(reminder + 1)"
                }
                lines.append(statusLine)
                
                if let focus = log.focusRating {
                    lines.append("Focus rating: \(focus)/5")
                }
                if let sideEffects = log.sideEffectSeverity {
                    lines.append("Side effects: \(sideEffects)/5")
                }
                if let notes = log.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    lines.append("Notes: \(notes)")
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
}

private struct HistoryStatCard: View {
    let title: String
    let value: String
    let detail: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.5)
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
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
