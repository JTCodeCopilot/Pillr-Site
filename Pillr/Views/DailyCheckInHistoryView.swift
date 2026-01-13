//
//  DailyCheckInHistoryView.swift
//  Pillr
//
//  Created by Codex on 2025-XX-XX.
//

import SwiftUI

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
                Color(hex: "#424C43")
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
                    Button(action: {
                        showingQuickCheckIn = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
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
                    Text("This check-in can't be edited right now.")
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
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            Text("\(checkInLogs.count) \(checkInLogs.count == 1 ? "entry" : "entries") logged")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.65))
        }
        .padding(.top, 16)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedCheckIns, id: \.date) { date, logs in
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
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)

                Rectangle()
                    .fill(Color.white.opacity(0.035))
                    .frame(width: 0.6)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .alignmentGuide(VerticalAlignment.center) { $0[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: 12) {
                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reflection log")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))

                        Text(medicationName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Text(timeText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                    }

                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            )
                    )

                    if let expandedNote {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))

                            Text(expandedNote)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !sideEffectChips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Side effects")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))

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
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Spacer()

                        Text(timeText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }

                    DailyCheckInScaleView(
                        label: "Feeling",
                        value: log.feelingRating,
                        isHero: true,
                        showValue: true,
                        layout: .inline
                    )

                    if log.focusRating != nil || log.sideEffectSeverity != nil {
                        HStack(alignment: .top, spacing: 16) {
                            if let focus = log.focusRating {
                                DailyCheckInScaleView(
                                    label: "Focus",
                                    value: focus,
                                    isHero: false,
                                    showValue: false,
                                    layout: .inline
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let sideEffects = log.sideEffectSeverity {
                                DailyCheckInScaleView(
                                    label: "Side effects",
                                    value: sideEffects,
                                    isHero: false,
                                    showValue: false,
                                    layout: .inline
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if let expandedNote {
                        Text(expandedNote)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isExpanded ? 14 : 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture {
                guard canExpand else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
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
        let indicatorWidth: CGFloat = isHero ? 22 : 16
        let indicatorHeight: CGFloat = isHero ? 8 : 6
        let indicatorSpacing: CGFloat = isHero ? 6 : 4
        let labelColor = isHero ? Color(hex: "#E8E8E0") : Color(hex: "#C7C7BD").opacity(0.9)

        Group {
            if layout == .inline {
                let labelWidth: CGFloat = 72
                let valueWidth: CGFloat = 32
                HStack(alignment: .center, spacing: isHero ? 10 : 8) {
                    Text(label)
                        .font(.system(size: isHero ? 12 : 11, weight: .semibold))
                        .foregroundColor(labelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: labelWidth, alignment: .leading)

                    HStack(spacing: indicatorSpacing) {
                        ForEach(0..<maxValue, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(index < clampedValue ? Color(hex: "#E1D6C5") : Color.white.opacity(0.12))
                                .frame(width: indicatorWidth, height: indicatorHeight)
                        }
                    }

                    if showValue {
                        Spacer(minLength: 6)
                        if value != nil {
                            Text("\(clampedValue)/\(maxValue)")
                                .font(.system(size: isHero ? 18 : 12, weight: isHero ? .bold : .semibold))
                                .foregroundColor(Color(hex: "#E1D6C5"))
                                .frame(minWidth: valueWidth, alignment: .trailing)
                        } else {
                            Text("Not logged")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: isHero ? 8 : 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(label)
                            .font(.system(size: isHero ? 12 : 11, weight: .semibold))
                            .foregroundColor(labelColor)

                        Spacer()

                        if showValue {
                            if value != nil {
                                Text("\(clampedValue)/\(maxValue)")
                                    .font(.system(size: isHero ? 19 : 12, weight: isHero ? .bold : .semibold))
                                    .foregroundColor(Color(hex: "#E1D6C5"))
                            } else {
                                Text("Not logged")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                            }
                        }
                    }

                    HStack(spacing: indicatorSpacing) {
                        ForEach(0..<maxValue, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(index < clampedValue ? Color(hex: "#E1D6C5") : Color.white.opacity(0.12))
                                .frame(width: indicatorWidth, height: indicatorHeight)
                        }
                    }
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
            .foregroundColor(Color(hex: "#C7C7BD"))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

private struct DailyCheckInRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "#E8E8E0"))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04))
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
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))

            Text("No check-ins yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            Text("Your reflection notes will show up here after you log.")
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
struct DailyCheckInHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        DailyCheckInHistoryView()
            .environmentObject(MedicationStore.previewStore())
    }
}
#endif
