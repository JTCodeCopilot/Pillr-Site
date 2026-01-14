//
//  DailyCheckInHistoryView.swift
//  Pillr
//
//  Created by Codex on 2025-XX-XX.
//


import SwiftUI

// MARK: - Premium journal styling
private enum ReflectJournalTheme {
    // Base palette
    static let pageTop = Color(hex: "#3E483F")
    static let pageBottom = Color(hex: "#303830")

    static let textPrimary = Color(hex: "#E8E8E0")
    static let textSecondary = Color(hex: "#C7C7BD").opacity(0.78)
    static let textTertiary = Color(hex: "#C7C7BD").opacity(0.55)

    // Paper
    static let sheetFill = Color.white.opacity(0.055)
    static let sheetFillExpanded = Color.white.opacity(0.065)
    static let sheetHighlight = Color.white.opacity(0.08)

    // Accents
    static let accent = Color(hex: "#E1D6C5")
    static let progressTrack = Color.white.opacity(0.10)

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
    @Environment(\.dismiss) private var dismiss
    let isModal: Bool
    @State private var showingQuickCheckIn = false
    @State private var editingLog: MedicationLog?

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

    private var selectableMedications: [Medication] {
        store.activeMedications.filter { !$0.isDeleted }
    }

    private var defaultMedicationForCheckIn: Medication? {
        selectableMedications.first
    }

    private var checkInLogs: [MedicationLog] {
        store.logs
            .filter { $0.isDailyCheckIn }
            .sorted { $0.takenAt > $1.takenAt }
    }

    private var groupedCheckIns: [(date: Date, logs: [MedicationLog])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: checkInLogs) { calendar.startOfDay(for: $0.takenAt) }

        return groups.keys.sorted(by: >).map { date in
            let logsForDay = groups[date]?.sorted(by: { $0.takenAt > $1.takenAt }) ?? []
            return (date, logsForDay)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ReflectJournalTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        if groupedCheckIns.isEmpty {
                            DailyCheckInEmptyState()
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
                    Text("Reflect")
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
                    Button(action: {
                        showingQuickCheckIn = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textSecondary)
                    }
                    .disabled(defaultMedicationForCheckIn == nil)
                    .accessibilityLabel("New Reflect")
                }
            }
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
                    Text("This Reflect entry can't be edited right now.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
                .padding(24)
                .background(Color(hex: "#424C43").ignoresSafeArea())
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Reflect")
                .journalTitle()

            Text("\(checkInLogs.count) \(checkInLogs.count == 1 ? "entry" : "entries") logged")
                .journalSubtitle()
        }
        .padding(.top, 16)
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
}

private struct DailyCheckInTimelineRow: View {
    let log: MedicationLog
    let timeText: String
    let isLast: Bool
    let onEdit: () -> Void
    @State private var isExpanded = false

    private var noteParts: (notes: String?, checkInNotes: String?, sideEffects: String?) {
        splitNotesAndSideEffects(for: log)
    }

    private var expandedNote: String? {
        let note = noteParts.checkInNotes ?? noteParts.notes
        return note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : note
    }

    private var sideEffectChips: [String] {
        guard let sideEffects = noteParts.sideEffects, !sideEffects.isEmpty else { return [] }
        return sideEffects
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canExpand: Bool {
        true
    }

    private var medicationName: String {
        let trimmedName = log.medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Medication" : trimmedName
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color.white.opacity(0.32))
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflection")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textTertiary)

                        HStack(alignment: .firstTextBaseline) {
                            Text(medicationName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textPrimary)

                            Spacer()

                            Text(timeText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ReflectJournalTheme.textSecondary)
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 10) {
                        DailyCheckInScaleView(
                            label: "Feeling",
                            value: log.feelingRating,
                            isHero: true,
                            showValue: true,
                            layout: .stacked
                        )

                        if let focus = log.focusRating {
                            DailyCheckInScaleView(
                                label: "Focus",
                                value: focus,
                                isHero: false,
                                showValue: false,
                                layout: .stacked
                            )
                        }

                        if let sideEffects = log.sideEffectSeverity {
                            DailyCheckInScaleView(
                                label: "Side effects",
                                value: sideEffects,
                                isHero: false,
                                showValue: false,
                                layout: .stacked
                            )
                        }
                    }

                    if let expandedNote {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ReflectJournalTheme.textTertiary)

                            Text(expandedNote)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ReflectJournalTheme.textPrimary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !sideEffectChips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Side effects")
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

                    Button(action: onEdit) {
                        HStack {
                            Label("Edit reflection", systemImage: "square.and.pencil")
                                .labelStyle(.titleAndIcon)
                            Spacer()
                        }
                    }
                    .buttonStyle(DailyCheckInRowButtonStyle())
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(medicationName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ReflectJournalTheme.textPrimary)

                        Spacer()

                        Text(timeText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ReflectJournalTheme.textTertiary)
                    }

                    // Feeling as the main, scannable metric
                    DailyCheckInScaleView(
                        label: "Feeling",
                        value: log.feelingRating,
                        isHero: true,
                        showValue: true,
                        layout: .stacked
                    )

                    // Secondary metrics in two concise columns
                    if log.focusRating != nil || log.sideEffectSeverity != nil {
                        HStack(alignment: .top, spacing: 14) {
                            DailyCheckInMiniMetric(label: "Focus", value: log.focusRating)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            DailyCheckInMiniMetric(label: "Side effects", value: log.sideEffectSeverity)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Notes preview
                    if let expandedNote {
                        Text(expandedNote)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(ReflectJournalTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .journalSheet(isExpanded: isExpanded)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture {
                guard canExpand else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
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
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReflectJournalTheme.textSecondary)

                Spacer()

                if let _ = value {
                    Text("\(clampedValue)/\(maxValue)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textTertiary)
                } else {
                    Text("Complete")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ReflectJournalTheme.textTertiary)
                }
            }

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(ReflectJournalTheme.progressTrack)

                Capsule(style: .continuous)
                    .fill(ReflectJournalTheme.accent)
                    .frame(width: max(0, fraction) * 1) // width set by GeometryReader below
            }
            .frame(height: 6)
            .overlay(
                GeometryReader { geo in
                    Capsule(style: .continuous)
                        .fill(ReflectJournalTheme.accent)
                        .frame(width: max(0, geo.size.width * fraction), height: 6)
                }
            )
            .mask(
                Capsule(style: .continuous)
            )
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

private struct DailyCheckInEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 42))
                .foregroundColor(ReflectJournalTheme.textTertiary)

            Text("No Reflect entries yet")
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

#if DEBUG
struct DailyCheckInHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        DailyCheckInHistoryView()
            .environmentObject(MedicationStore.previewStore())
    }
}
#endif
