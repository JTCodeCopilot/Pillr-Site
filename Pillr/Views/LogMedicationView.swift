//
//  LogMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import UIKit

	struct LogMedicationView: View {
	    @EnvironmentObject var store: MedicationStore
	    @Environment(\.dismiss) var dismiss
	    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
	    @Environment(\.colorScheme) private var colorScheme

	    @State private var medicationToLog: Medication
	    var isDailyCheckIn: Bool
        var checkInLogID: UUID?
        var allowsMedicationSelection: Bool
	    var onLogAction: ((MedicationStore.LogUndoAction) -> Void)?
	    @State private var actualTimeTaken: Date = Date()
	    @State private var logNotes: String = ""
	    @State private var keyboardHeight: CGFloat = 0
	    @State private var remainingPills: Int?
    @State private var selectedDoseIndex: Int = 0
    @State private var showQuickLogOption: Bool = false
    @State private var selectedQuickTime: QuickTimeOption = .now
    @State private var showingCustomTime: Bool = false
    @State private var sideEffectTags: Set<String> = []
    @State private var customSideEffect: String = ""
    @State private var showingAddCustomSideEffect: Bool = false
    @State private var focusRating: Int = 0 // 1–5, 0 = not set
    @State private var feelingRating: Int = 0 // 1–5, 0 = not set
    @State private var sideEffectSeverity: Int = 0 // 1–5, 0 = not set
    @State private var checkInDate: Date = Date()
    @State private var didLoadExistingCheckIn: Bool = false
    init(
        medicationToLog: Medication,
        isDailyCheckIn: Bool = false,
        checkInLogID: UUID? = nil,
        allowsMedicationSelection: Bool = false,
        onLogAction: ((MedicationStore.LogUndoAction) -> Void)? = nil
    ) {
        self._medicationToLog = State(initialValue: medicationToLog)
        self.isDailyCheckIn = isDailyCheckIn
        self.checkInLogID = checkInLogID
        self.allowsMedicationSelection = allowsMedicationSelection
        self.onLogAction = onLogAction
    }

    // Quick time options for easier logging
    enum QuickTimeOption: String, CaseIterable {
        case now = "Now"
        case fiveMinAgo = "5 min ago"
        case fifteenMinAgo = "15 min ago"
        case thirtyMinAgo = "30 min ago"
        case oneHourAgo = "1 hour ago"
        case custom = "Custom time"
        
        var timeOffset: TimeInterval {
            switch self {
            case .now: return 0
            case .fiveMinAgo: return -300
            case .fifteenMinAgo: return -900
            case .thirtyMinAgo: return -1800
            case .oneHourAgo: return -3600
            case .custom: return 0
            }
        }
    }

    // Common side effects for quick selection
    private let commonSideEffects = [
        "Nausea", "Drowsiness", "Headache", "Dizziness", "Stomach upset",
        "Dry mouth", "Fatigue", "Insomnia", "Appetite loss", "Mood changes"
    ]
    
    // Whether this medication has multiple doses
    private var hasMultipleDoses: Bool {
        return !medicationToLog.reminderTimes.isEmpty
    }

    private var selectableMedications: [Medication] {
        store.activeMedications.filter { !$0.isDeleted }
    }

    private var shouldShowMedicationSelection: Bool {
        isDailyCheckIn && allowsMedicationSelection
    }

    private var medicationSelectionLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: medicationToLog.iconName.isEmpty ? "pill" : medicationToLog.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            VStack(alignment: .leading, spacing: 2) {
                Text(medicationToLog.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))

                if !medicationToLog.dosageWithUnit.isEmpty {
                    Text(medicationToLog.dosageWithUnit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                }
            }

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    // Computed property for dose selection label to avoid complex expression
    private var doseSelectionLabel: some View {
        HStack {
            Text("Dose #\(selectedDoseIndex + 1) (\(formatTime(medicationToLog.reminderTimes[selectedDoseIndex])))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#3C463E"),
                        Color(hex: "#343D36")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isDailyCheckIn ? "Reflect" : "Log Medication")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                }
                                
                                Spacer()
                                
                                // Pill count indicator
                                if let pillCount = remainingPills {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "pills.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                            Text("\(pillCount)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                        }
                                        Text("remaining")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    )
                                }
                            }

                            if shouldShowMedicationSelection {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Medication")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                        .tracking(0.6)

                                    Menu {
                                        ForEach(selectableMedications) { medication in
                                            Button {
                                                applyMedicationSelection(medication)
                                            } label: {
                                                Text(medication.name)
                                            }
                                        }
                                    } label: {
                                        medicationSelectionLabel
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(selectableMedications.isEmpty)
                                }
                            }
                            
                    }
                    .padding(.top, 20)
                        
                        // Multiple doses selector (if applicable)
                        if hasMultipleDoses {
                            FormSection(title: "DOSE SELECTION", icon: "list.number.circle.fill") {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "clock.badge.checkmark")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .font(.system(size: 18))
                                        Text("Which dose are you logging?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                    }
                                    
                                    Menu {
                                        ForEach(0..<medicationToLog.reminderTimes.count, id: \.self) { index in
                                            Button("Dose #\(index + 1) (\(formatTime(medicationToLog.reminderTimes[index])))") {
                                                selectedDoseIndex = index
                                            }
                                        }
                                    } label: {
                                        doseSelectionLabel
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                        
                        // Enhanced Time Section with quick options (hidden for Reflect)
                        if !isDailyCheckIn {
                            FormSection(title: "TIME TAKEN", icon: "") {
                                VStack(alignment: .leading, spacing: 20) {
                                    // Quick time selection buttons
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                        ForEach(QuickTimeOption.allCases, id: \.self) { option in
                                            Button(action: {
                                                HapticManager.shared.lightImpact()
                                                selectedQuickTime = option
                                                if option == .custom {
                                                    showingCustomTime = true
                                                } else {
                                                    actualTimeTaken = Date().addingTimeInterval(option.timeOffset)
                                                    showingCustomTime = false
                                                }
                                            }) {
                                                Text(option.rawValue)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(selectedQuickTime == option ? Color(hex: "#E8E8E0") : Color(hex: "#C7C7BD"))
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(selectedQuickTime == option ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color.white.opacity(selectedQuickTime == option ? 0.2 : 0.12), lineWidth: 1)
                                                            )
                                                    )
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                    
                                    // Custom time picker (shown when custom is selected)
                                    if showingCustomTime {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                    .font(.system(size: 16))
                                                Text("Select custom time")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                            }
                                            
                                            DatePicker("", selection: $actualTimeTaken, displayedComponents: [.date, .hourAndMinute])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                                .colorScheme(.dark)
                                                .accentColor(Color(hex: "#F5F5F5"))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.white.opacity(0.05))
                                                )
                                        }
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.04))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                )
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }
                                }
                            }
                        }

                        if isDailyCheckIn {
                            VStack(alignment: .leading, spacing: 14) {
                                ReflectCard {
                                    Text("Which day are you reflecting on?")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))

                                    DatePicker(
                                        "",
                                        selection: $checkInDate,
                                        in: ...Date(),
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(Color(hex: "#F5F5F5"))
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.05))
                                    )
                                }

                                if medicationToLog.medicationType == .stimulant {
                                    ReflectCard {
                                        Text("How did you feel today?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))

                                        RatingControl(
                                            title: "Feeling",
                                            value: $feelingRating,
                                            lowLabel: "Rough",
                                            highLabel: "Great"
                                        )
                                    }

                                    if feelingRating > 0 {
                                        ReflectCard {
                                            Text("How was your focus?")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            RatingControl(
                                                title: "Focus",
                                                value: $focusRating,
                                                lowLabel: "Foggy",
                                                highLabel: "Very focused"
                                            )
                                        }
                                    }

                                    if focusRating > 0 {
                                        ReflectCard {
                                            Text("How strong were side effects?")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            RatingControl(
                                                title: "Side effects",
                                                value: $sideEffectSeverity,
                                                lowLabel: "Barely noticed",
                                                highLabel: "Very strong"
                                            )
                                        }
                                    }

                                    if sideEffectSeverity > 0 || !sideEffectTags.isEmpty {
                                        ReflectCard {
                                            Text("Any side effects? (optional)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            if !sideEffectTags.isEmpty {
                                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                                                    ForEach(Array(sideEffectTags), id: \.self) { effect in
                                                        HStack(spacing: 8) {
                                                            Text(effect)
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                                                .lineLimit(1)
                                                                .truncationMode(.tail)

                                                            Button(action: {
                                                                HapticManager.shared.lightImpact()
                                                                sideEffectTags.remove(effect)
                                                            }) {
                                                                Image(systemName: "xmark.circle.fill")
                                                                    .font(.system(size: 16))
                                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                            }
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                .fill(Color.white.opacity(0.08))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                                                )
                                                        )
                                                    }
                                                }
                                            }

                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(commonSideEffects.filter { !sideEffectTags.contains($0) }, id: \.self) { effect in
                                                        Button(action: {
                                                            HapticManager.shared.lightImpact()
                                                            sideEffectTags.insert(effect)
                                                        }) {
                                                            Text(effect)
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 8)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 20)
                                                                        .fill(Color.white.opacity(0.04))
                                                                        .overlay(
                                                                            RoundedRectangle(cornerRadius: 20)
                                                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                                        )
                                                                )
                                                        }
                                                        .buttonStyle(ScaleButtonStyle())
                                                    }

                                                    Button(action: {
                                                        showingAddCustomSideEffect = true
                                                    }) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "plus.circle")
                                                                .font(.system(size: 14))
                                                            Text("Add custom")
                                                                .font(.system(size: 14, weight: .medium))
                                                        }
                                                        .foregroundColor(Color(hex: "#F5F5F5"))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill(Color.white.opacity(0.04))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 20)
                                                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                                                )
                                                        )
                                                    }
                                                    .buttonStyle(ScaleButtonStyle())
                                                }
                                                .padding(.horizontal, 1)
                                            }
                                        }
                                    }

                                    if sideEffectSeverity > 0 || !logNotes.isEmpty {
                                        ReflectCard {
                                            Text("Additional notes (optional)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            ZStack(alignment: .topLeading) {
                                                TextEditor(text: $logNotes)
                                                    .frame(minHeight: 80, maxHeight: 150)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                    .scrollContentBackground(.hidden)
                                                    .background(Color.clear)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.white.opacity(0.05))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                            )
                                                    )

                                                if logNotes.isEmpty {
                                                    Text("How did you feel? Any observations?")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                        .padding(.leading, 20)
                                                        .padding(.top, 20)
                                                        .allowsHitTesting(false)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    ReflectCard {
                                        Text("How did you feel today?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))

                                        RatingControl(
                                            title: "Feeling",
                                            value: $feelingRating,
                                            lowLabel: "Rough",
                                            highLabel: "Great"
                                        )
                                    }

                                    if feelingRating > 0 {
                                        ReflectCard {
                                            Text("Overall, how was your day?")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            RatingControl(
                                                title: "Overall",
                                                value: $focusRating,
                                                lowLabel: "Rough",
                                                highLabel: "Great"
                                            )
                                        }
                                    }

                                    if focusRating > 0 {
                                        ReflectCard {
                                            Text("How strong were side effects?")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            RatingControl(
                                                title: "Side effects",
                                                value: $sideEffectSeverity,
                                                lowLabel: "Barely noticed",
                                                highLabel: "Very strong"
                                            )
                                        }
                                    }

                                    if sideEffectSeverity > 0 || !sideEffectTags.isEmpty {
                                        ReflectCard {
                                            Text("Any side effects? (optional)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            if !sideEffectTags.isEmpty {
                                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                                                    ForEach(Array(sideEffectTags), id: \.self) { effect in
                                                        HStack(spacing: 8) {
                                                            Text(effect)
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                                                .lineLimit(1)
                                                                .truncationMode(.tail)

                                                            Button(action: {
                                                                HapticManager.shared.lightImpact()
                                                                sideEffectTags.remove(effect)
                                                            }) {
                                                                Image(systemName: "xmark.circle.fill")
                                                                    .font(.system(size: 16))
                                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                            }
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                .fill(Color.white.opacity(0.08))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                                                )
                                                        )
                                                    }
                                                }
                                            }

                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(commonSideEffects.filter { !sideEffectTags.contains($0) }, id: \.self) { effect in
                                                        Button(action: {
                                                            HapticManager.shared.lightImpact()
                                                            sideEffectTags.insert(effect)
                                                        }) {
                                                            Text(effect)
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 8)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 20)
                                                                        .fill(Color.white.opacity(0.04))
                                                                        .overlay(
                                                                            RoundedRectangle(cornerRadius: 20)
                                                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                                        )
                                                                )
                                                        }
                                                        .buttonStyle(ScaleButtonStyle())
                                                    }

                                                    Button(action: {
                                                        showingAddCustomSideEffect = true
                                                    }) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "plus.circle")
                                                                .font(.system(size: 14))
                                                            Text("Add custom")
                                                                .font(.system(size: 14, weight: .medium))
                                                        }
                                                        .foregroundColor(Color(hex: "#F5F5F5"))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill(Color.white.opacity(0.04))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 20)
                                                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                                                )
                                                        )
                                                    }
                                                    .buttonStyle(ScaleButtonStyle())
                                                }
                                                .padding(.horizontal, 1)
                                            }
                                        }
                                    }

                                    if sideEffectSeverity > 0 || !logNotes.isEmpty {
                                        ReflectCard {
                                            Text("Additional notes (optional)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))

                                            ZStack(alignment: .topLeading) {
                                                TextEditor(text: $logNotes)
                                                    .frame(minHeight: 80, maxHeight: 150)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                    .scrollContentBackground(.hidden)
                                                    .background(Color.clear)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.white.opacity(0.05))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                            )
                                                    )

                                                if logNotes.isEmpty {
                                                    Text("How did you feel? Any observations?")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                        .padding(.leading, 20)
                                                        .padding(.top, 20)
                                                        .allowsHitTesting(false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            FormSection(title: "NOTES (OPTIONAL)", icon: "note.text.fill") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $logNotes)
                                            .frame(minHeight: 80, maxHeight: 120)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                            .scrollContentBackground(.hidden)
                                            .background(Color.clear)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.05))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                    )
                                            )
                                        
                                        if logNotes.isEmpty {
                                            Text("Add anything you want to remember for this dose.")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                .padding(.leading, 20)
                                                .padding(.top, 20)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Enhanced Action Buttons
                        VStack(spacing: 16) {
                            Button {
                                HapticManager.shared.successNotification()
                                processDoseAction(skipped: false)
                            } label: {
                                Text("Log Medication")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "#2C332D"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(hex: "#E8E8E0"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.vertical, 20)
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
                        }
                        .padding(.horizontal, 20)
                        .id("reflectScrollAnchor")
                    }
                    .onChange(of: feelingRating) { _ in
                        guard isDailyCheckIn else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("reflectScrollAnchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: focusRating) { _ in
                        guard isDailyCheckIn else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("reflectScrollAnchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: sideEffectSeverity) { _ in
                        guard isDailyCheckIn else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("reflectScrollAnchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: sideEffectTags) { _ in
                        guard isDailyCheckIn else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("reflectScrollAnchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: logNotes) { _ in
                        guard isDailyCheckIn, !logNotes.isEmpty else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("reflectScrollAnchor", anchor: .bottom)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .onAppear {
                setupKeyboardObservers()
                // Initialize remaining pills if pill count is available
                if let pillCount = medicationToLog.pillCount {
                    remainingPills = pillCount
                }
                loadExistingCheckInIfNeeded()
            }
            .onChange(of: medicationToLog.id) { _ in
                selectedDoseIndex = 0
                remainingPills = medicationToLog.pillCount
            }
            .alert("Add Custom Side Effect", isPresented: $showingAddCustomSideEffect) {
                TextField("Side effect", text: $customSideEffect)
                Button("Add") {
                    if !customSideEffect.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sideEffectTags.insert(customSideEffect.trimmingCharacters(in: .whitespacesAndNewlines))
                        customSideEffect = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    customSideEffect = ""
                }
            } message: {
                Text("Enter a custom side effect to track with this dose.")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct ReflectCard<Content: View>: View {
        let content: Content

        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private func FormSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !title.isEmpty || !icon.isEmpty {
                HStack {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    if !title.isEmpty {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                            .tracking(0.6)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }

    private func applyMedicationSelection(_ medication: Medication) {
        medicationToLog = medication
        selectedDoseIndex = 0
        remainingPills = medication.pillCount
    }
    
    private func setupKeyboardObservers() {
        // Add keyboard observers
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = keyboardFrame.height
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
    
	    private func processDoseAction(skipped: Bool) {
        // Use the selected time instead of current time
        let timeToUse: Date
        if isDailyCheckIn {
            timeToUse = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: checkInDate) ?? checkInDate
        } else {
            timeToUse = selectedQuickTime == .custom ? actualTimeTaken : Date().addingTimeInterval(selectedQuickTime.timeOffset)
        }
        
        // Combine notes with side effects
        var combinedNotes = logNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isDailyCheckIn && !sideEffectTags.isEmpty {
            let sideEffectsText = "Side effects: " + Array(sideEffectTags).joined(separator: ", ")
            if combinedNotes.isEmpty {
                combinedNotes = sideEffectsText
            } else {
                combinedNotes += "\n\n" + sideEffectsText
            }
        }
        
        let finalNotes = combinedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave = finalNotes.isEmpty ? nil : finalNotes
        
        let feelingToSave = isDailyCheckIn && feelingRating > 0 ? feelingRating : nil
        let focusToSave = isDailyCheckIn && focusRating > 0 ? focusRating : nil
        let sideEffectToSave = isDailyCheckIn && sideEffectSeverity > 0 ? sideEffectSeverity : nil
        
	        if skipped {
	            if let action = store.skipMedication(
	                medication: medicationToLog,
	                actualTime: timeToUse,
	                notes: notesToSave,
	                reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil,
	                feelingRating: feelingToSave,
	                focusRating: focusToSave,
	                sideEffectSeverity: sideEffectToSave,
	                showFocusTimeline: !isDailyCheckIn
	            ) {
	                onLogAction?(action)
	            }
	        } else {
	            if let action = store.logMedicationTaken(
	                medication: medicationToLog,
	                actualTime: timeToUse,
	                notes: notesToSave,
	                skipped: false,
	                reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil,
	                feelingRating: feelingToSave,
	                focusRating: focusToSave,
	                sideEffectSeverity: sideEffectToSave,
	                showFocusTimeline: !isDailyCheckIn,
	                isDailyCheckIn: isDailyCheckIn
	            ) {
	                onLogAction?(action)
	            }
	        }

	        dismiss()
	    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func calculateTextEditorHeight(for size: CGSize) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 120
        } else {
            return size.height < 700 ? 80 : 100
        }
    }

    private func loadExistingCheckInIfNeeded() {
        guard isDailyCheckIn, !didLoadExistingCheckIn, let checkInLogID else { return }
        guard let log = store.logs.first(where: { $0.id == checkInLogID }) else {
            didLoadExistingCheckIn = true
            return
        }

        checkInDate = log.takenAt
        feelingRating = log.feelingRating ?? 0
        focusRating = log.focusRating ?? 0
        sideEffectSeverity = log.sideEffectSeverity ?? 0

        let noteParts = splitNotesAndSideEffects(from: log.notes)
        logNotes = noteParts.checkInNotes ?? noteParts.notes ?? ""
        sideEffectTags = Set(noteParts.sideEffectsList)

        didLoadExistingCheckIn = true
    }

    private func splitNotesAndSideEffects(from notes: String?) -> (notes: String?, checkInNotes: String?, sideEffectsList: [String]) {
        guard var raw = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (nil, nil, [])
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
            if feelingRating > 0 || focusRating > 0 || sideEffectSeverity > 0 {
                checkInNote = first
            } else {
                generalNote = first
            }
        }

        let sideEffectsList = sideEffectsPart?
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        return (
            generalNote?.isEmpty == true ? nil : generalNote,
            checkInNote?.isEmpty == true ? nil : checkInNote,
            sideEffectsList
        )
    }
}

// MARK: - Rating Control

struct RatingControl: View {
    let title: String
    @Binding var value: Int
    let lowLabel: String
    let highLabel: String
    let activeColor: Color
    
    private let range = 1...5
    
    init(
        title: String,
        value: Binding<Int>,
        lowLabel: String,
        highLabel: String,
        activeColor: Color = Color(hex: "#D7CCC8")
    ) {
        self.title = title
        self._value = value
        self.lowLabel = lowLabel
        self.highLabel = highLabel
        self.activeColor = activeColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if value == 0 {
                HStack(spacing: 8) {
                    Text(lowLabel)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))

                    Spacer()

                    Text(highLabel)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                }
            }
            
            HStack(spacing: 8) {
                ForEach(range, id: \.self) { index in
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        if value == index {
                            value = 0
                        } else {
                            value = index
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                index <= value
                                ? activeColor
                                : Color.white.opacity(0.06)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(hex: "#C7C7BD").opacity(0.4), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if index == value {
                                        Text("\(index)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color.black.opacity(0.35))
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}
