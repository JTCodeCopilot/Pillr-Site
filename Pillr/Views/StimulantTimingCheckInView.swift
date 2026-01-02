//
//  StimulantTimingCheckInView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct StimulantTimingCheckInView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) private var dismiss

    let context: StimulantTimingCheckInContext

    @State private var selectedTime: Date = Date()
    @State private var showingTimePicker = false
    @State private var onsetSelectedTime: Date = Date()
    @State private var showingOnsetPicker = false
    @State private var errorMessage: String? = nil

    private var logEntry: MedicationLog? {
        store.logs.first { $0.id == context.logID }
    }

    private var isCalibrationEnabled: Bool {
        store.findMedication(with: context.medication.id)?.enableTimingCalibration
            ?? context.medication.enableTimingCalibration
    }

    private var promptTitle: String {
        context.phase == .onset ? "Is it starting to work?" : "Is it wearing off?"
    }

    private var promptSubtitle: String {
        switch context.phase {
        case .onset:
            return "Tap when you first felt it kick in."
        case .fade:
            return "Tap when you first felt it start to wear off."
        }
    }

    private var shouldOfferOnsetLogging: Bool {
        context.phase == .fade && logEntry?.reportedOnsetMinutes == nil
    }

    private var estimatedOnsetMinutes: Int {
        if let medication = store.findMedication(with: context.medication.id),
           let onset = medication.onsetMinutes {
            return onset
        }
        return 45
    }

    private var estimatedOnsetTime: Date? {
        guard let logEntry else { return nil }
        return Calendar.current.date(byAdding: .minute, value: estimatedOnsetMinutes, to: logEntry.takenAt)
    }

    private var estimatedOnsetLabel: String {
        guard let estimatedOnsetTime else { return "Use suggested time" }
        return "Use suggested time (\(formatTime(estimatedOnsetTime)))"
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
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard

                        if !isCalibrationEnabled {
                            calibrationDisabledCard
                        } else if let logEntry {
                            timingCard(for: logEntry)
                        } else {
                            missingLogCard
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#E8E8E0"))
                }
            }
            .onAppear {
                if shouldOfferOnsetLogging,
                   let estimatedOnsetTime {
                    onsetSelectedTime = estimatedOnsetTime
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.medication.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#F5F7F4"))

            Text(promptTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            Text(promptSubtitle)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(cornerRadius: 22))
    }

    private var calibrationDisabledCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timing check-ins are off for this medication.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#E0E7DC"))

            Text("You can turn them back on in the focus window settings.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#404C42"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(primaryButtonBackground())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(cardBackground(cornerRadius: 20))
    }

    private var missingLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We couldn't find the dose this check-in refers to.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#E0E7DC"))

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#404C42"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(primaryButtonBackground())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(cardBackground(cornerRadius: 20))
    }

    @ViewBuilder
    private func timingCard(for logEntry: MedicationLog) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dose logged at \(formatTime(logEntry.takenAt)).")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFB74D"))
            }

            HStack(spacing: 12) {
                Button {
                    logTiming(at: Date())
                } label: {
                    Text("Log now")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#404C42"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryButtonBackground())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    showingTimePicker.toggle()
                } label: {
                    Text("Pick time")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(secondaryButtonBackground())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if showingTimePicker {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        "Select time",
                        selection: $selectedTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(Color.pillrAccent)

                    Button {
                        logTiming(at: selectedTime)
                    } label: {
                        Text("Save time")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#404C42"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(primaryButtonBackground(cornerRadius: 12))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(14)
                .background(insetCardBackground(cornerRadius: 14))
            }

            if shouldOfferOnsetLogging {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Missed the kick-in check-in?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))

                    Text("Optional. You can still log when it started working.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))

                    HStack(spacing: 12) {
                        Button {
                            logKickIn(at: estimatedOnsetTime ?? Date())
                        } label: {
                            Text(estimatedOnsetLabel)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#404C42"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(primaryButtonBackground(cornerRadius: 12))
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Button {
                            showingOnsetPicker.toggle()
                        } label: {
                            Text("Pick time")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(secondaryButtonBackground(cornerRadius: 12))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    if showingOnsetPicker {
                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker(
                                "Select time",
                                selection: $onsetSelectedTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .accentColor(Color.pillrAccent)

                            Button {
                                logKickIn(at: onsetSelectedTime)
                            } label: {
                                Text("Save kick-in time")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(primaryButtonBackground(cornerRadius: 12))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(12)
                        .background(insetCardBackground(cornerRadius: 12))
                    }
                }
                .padding(16)
                .background(insetCardBackground(cornerRadius: 16))
            }

            if context.phase == .fade {
                Button {
                    scheduleWearOffReminder()
                } label: {
                    Text("Remind me in 1 hr")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .selection))
            } else {
                Button {
                    dismiss()
                } label: {
                    Text("Not yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .selection))
            }
        }
        .padding(20)
        .background(cardBackground(cornerRadius: 20))
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
            )
    }

    private func insetCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(hex: "#C7C7BD").opacity(0.18), lineWidth: 1)
            )
    }

    private func primaryButtonBackground(cornerRadius: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.pillrAccent)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    private func secondaryButtonBackground(cornerRadius: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(hex: "#C7C7BD").opacity(0.35), lineWidth: 1)
            )
    }

    private func logTiming(at time: Date) {
        guard isCalibrationEnabled else {
            errorMessage = "Timing check-ins are off for this medication."
            return
        }
        guard store.applyTimingCheckIn(
            medicationID: context.medication.id,
            logID: context.logID,
            phase: context.phase,
            reportedTime: time
        ) else {
            errorMessage = "That time is before the dose was logged. Try again."
            return
        }
        dismiss()
    }

    private func logKickIn(at time: Date) {
        guard isCalibrationEnabled else {
            errorMessage = "Timing check-ins are off for this medication."
            return
        }
        guard store.applyTimingCheckIn(
            medicationID: context.medication.id,
            logID: context.logID,
            phase: .onset,
            reportedTime: time
        ) else {
            errorMessage = "That time is before the dose was logged. Try again."
            return
        }
        errorMessage = nil
    }

    private func scheduleWearOffReminder() {
        guard isCalibrationEnabled else {
            errorMessage = "Timing check-ins are off for this medication."
            return
        }
        guard store.scheduleTimingCheckInReminder(
            medicationID: context.medication.id,
            logID: context.logID,
            phase: context.phase,
            afterMinutes: 60
        ) else {
            errorMessage = "Couldn't schedule a reminder. Try again."
            return
        }
        dismiss()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
