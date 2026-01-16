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
        @ObservedObject private var userSettings = UserSettings.shared

	    @State private var medicationToLog: Medication
	    var isDailyCheckIn: Bool
        var isNotificationEntry: Bool
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
    @State private var isEditingCustomSideEffects: Bool = false
    @State private var focusRating: Int = 0 // 1–5, 0 = not set
    @State private var feelingRating: Int = 0 // 1–5, 0 = not set
    @State private var sideEffectSeverity: Int = 0 // 1–5, 0 = not set
    @State private var emotionalTone: EmotionalTone?
    @State private var checkInDate: Date = Date()
    @State private var didLoadExistingCheckIn: Bool = false
    @State private var currentReflectStepIndex: Int = 0
    @State private var reflectStepAnimationDirection: ReflectStepTransitionDirection = .forward
    @State private var showingReflectionSummary = false
    @State private var isGeneratingReflectionSummary = false
    @State private var reflectionSummaryText: String = ""
    @State private var reflectionSummaryError: String?
    init(
        medicationToLog: Medication,
        isDailyCheckIn: Bool = false,
        isNotificationEntry: Bool = false,
        checkInLogID: UUID? = nil,
        allowsMedicationSelection: Bool = false,
        onLogAction: ((MedicationStore.LogUndoAction) -> Void)? = nil
    ) {
        self._medicationToLog = State(initialValue: medicationToLog)
        self.isDailyCheckIn = isDailyCheckIn
        self.isNotificationEntry = isNotificationEntry
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

    private enum ReflectStep {
        case date
        case feeling
        case emotionalTone
        case focusOrOverall
        case sideEffectsSeverity
        case sideEffectsTags
        case notes
    }

    private enum EmotionalTone: String, CaseIterable {
        case flat
        case calm
        case tense
        case overstimulated

        var label: String {
            rawValue.capitalized
        }
    }

    private enum ReflectStepTransitionDirection {
        case forward
        case backward
    }

    // Common side effects for quick selection
    private let commonSideEffects = [
        "Nausea", "Drowsiness", "Headache", "Dizziness", "Stomach upset",
        "Dry mouth", "Fatigue", "Insomnia", "Appetite loss", "Mood changes"
    ]

    private var availableSideEffects: [String] {
        var seen = Set<String>()
        return (commonSideEffects + userSettings.customSideEffects).filter { effect in
            let key = effect.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func isCustomSideEffect(_ effect: String) -> Bool {
        userSettings.customSideEffects.contains { $0.caseInsensitiveCompare(effect) == .orderedSame }
    }
    
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

    private static let reflectDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var reflectSteps: [ReflectStep] {
        var steps: [ReflectStep] = []
        if !isNotificationEntry {
            steps.append(.date)
        }
        steps.append(.feeling)
        if medicationToLog.medicationType == .stimulant {
            steps.append(.focusOrOverall)
            steps.append(.emotionalTone)
        }
        steps.append(.sideEffectsTags)
        steps.append(.sideEffectsSeverity)
        steps.append(.notes)
        return steps
    }

    private var clampedReflectStepIndex: Int {
        guard !reflectSteps.isEmpty else { return 0 }
        return min(max(currentReflectStepIndex, 0), reflectSteps.count - 1)
    }

    private var currentReflectStep: ReflectStep {
        reflectSteps[clampedReflectStepIndex]
    }

    private var isLastReflectStep: Bool {
        clampedReflectStepIndex >= reflectSteps.count - 1
    }

    private var reflectStepIndicatorText: String {
        "Step \(clampedReflectStepIndex + 1) of \(reflectSteps.count)"
    }

    private var canAdvanceReflectStep: Bool {
        switch currentReflectStep {
        case .feeling:
            return feelingRating > 0
        default:
            return true
        }
    }

    private var reflectStepTransition: AnyTransition {
        let insertionEdge: Edge = reflectStepAnimationDirection == .forward ? .trailing : .leading
        let removalEdge: Edge = reflectStepAnimationDirection == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
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
                                    Text(isDailyCheckIn ? "Reflection" : "Log Medication")
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

                            if isDailyCheckIn {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(reflectStepIndicatorText)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                        .tracking(0.6)

                                    ProgressView(
                                        value: Double(clampedReflectStepIndex + 1),
                                        total: Double(max(reflectSteps.count, 1))
                                    )
                                    .tint(Color(hex: "#C7C7BD"))
                                    .scaleEffect(x: 1, y: 1.4, anchor: .center)
                                }
                            }

                            if shouldShowMedicationSelection && !isDailyCheckIn {
                                medicationSelectionSection
                            }
                            
                    }
                    .padding(.top, isDailyCheckIn ? 8 : 20)
                        
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
                        
                        // Enhanced Time Section with quick options (hidden for Reflection)
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
                            reflectPagedSection
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
                        
                        if !isDailyCheckIn {
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
                        }
                        .padding(.horizontal, 20)
                        .id("reflectScrollAnchor")
                    }
                }
            }
            .overlay {
                if showingReflectionSummary {
                    reflectionSummaryOverlay
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
                if isDailyCheckIn, isNotificationEntry, checkInLogID == nil {
                    checkInDate = Date()
                }
                loadExistingCheckInIfNeeded()
            }
            .onChange(of: medicationToLog.id) { _ in
                selectedDoseIndex = 0
                remainingPills = medicationToLog.pillCount
                emotionalTone = nil
            }
            .alert("Add Custom Side Effect", isPresented: $showingAddCustomSideEffect) {
                TextField("Side effect", text: $customSideEffect)
                Button("Add") {
                    let trimmed = customSideEffect.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        userSettings.addCustomSideEffect(trimmed)
                        sideEffectTags.insert(trimmed)
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

    private var reflectPagedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            reflectSummarySection
            if shouldShowMedicationSelection && currentReflectStep == .date {
                medicationSelectionSection
            }

            reflectQuestionCard

            reflectNavigationButtons
        }
        .padding(.top, 6)
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
    }

    private var reflectSummarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OVERVIEW")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                .tracking(0.5)

            reflectSummaryCard
        }
    }

    private var reflectSummaryCard: some View {
        let focusLabel = "Focus"
        let focusValue = focusRating > 0 ? "\(focusRating)/5" : "Not set"
        let effectsValue = sideEffectTags.isEmpty ? "Not set" : "\(sideEffectTags.count) selected"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                reflectSummaryRow(title: "Medication", value: medicationToLog.name.isEmpty ? "Not set" : medicationToLog.name)
                reflectSummaryRow(title: "Date", value: Self.reflectDateFormatter.string(from: checkInDate))
            }

            if medicationToLog.medicationType == .stimulant {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    reflectSummaryRow(title: "Feeling", value: feelingRating > 0 ? "\(feelingRating)/5" : "Not set")
                    reflectSummaryRow(title: focusLabel, value: focusValue)
                }
            } else {
                reflectSummaryRow(title: "Feeling", value: feelingRating > 0 ? "\(feelingRating)/5" : "Not set")
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                reflectSummaryRow(title: "Side effects", value: sideEffectSeverity > 0 ? "\(sideEffectSeverity)/5" : "Not set")
                reflectSummaryRow(title: "Effects", value: effectsValue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var medicationSelectionSection: some View {
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

    private var reflectQuestionCard: some View {
        ZStack(alignment: .topLeading) {
            switch currentReflectStep {
            case .date:
                reflectDateQuestion
                    .transition(reflectStepTransition)
            case .feeling:
                reflectFeelingQuestion
                    .transition(reflectStepTransition)
            case .emotionalTone:
                reflectEmotionalToneQuestion
                    .transition(reflectStepTransition)
            case .focusOrOverall:
                reflectFocusQuestion
                    .transition(reflectStepTransition)
            case .sideEffectsSeverity:
                reflectSideEffectSeverityQuestion
                    .transition(reflectStepTransition)
            case .sideEffectsTags:
                reflectSideEffectsTagsQuestion
                    .transition(reflectStepTransition)
            case .notes:
                reflectNotesQuestion
                    .transition(reflectStepTransition)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: clampedReflectStepIndex)
    }

    private var reflectDateQuestion: some View {
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
    }

    private var reflectFeelingQuestion: some View {
        ReflectCard {
            Text("Overall, how was your day today?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            RatingControl(
                title: "Feeling",
                value: $feelingRating,
                lowLabel: "Rough",
                highLabel: "Great"
            )
        }
    }

    private var reflectEmotionalToneQuestion: some View {
        ReflectCard {
            Text("Did you feel:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(EmotionalTone.allCases, id: \.self) { tone in
                    Button(action: {
                        HapticManager.shared.strongImpact()
                        emotionalTone = emotionalTone == tone ? nil : tone
                    }) {
                        Text(tone.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(emotionalTone == tone ? Color(hex: "#2C332D") : Color(hex: "#E8E8E0"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(emotionalTone == tone ? Color(hex: "#E8E8E0") : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.35), lineWidth: 1)
                                    )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                legendLine(term: "Flat", description: "very low energy or emotional activation")
                legendLine(term: "Calm", description: "balanced baseline")
                legendLine(term: "Tense", description: "elevated activation or stress")
                legendLine(term: "Overstimulated", description: "very high activation or overload")
            }
        }
    }

    private func legendLine(term: String, description: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(term)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
            Text("= \(description)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.85))
        }
    }


    private var reflectFocusQuestion: some View {
        let isStimulant = medicationToLog.medicationType == .stimulant
        return ReflectCard {
            Text(isStimulant ? "How was your focus today?" : "Overall, how was your day?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            RatingControl(
                title: isStimulant ? "Focus" : "Overall",
                value: $focusRating,
                lowLabel: isStimulant ? "Foggy" : "Rough",
                highLabel: isStimulant ? "Very focused" : "Great"
            )
        }
    }

    private var reflectSideEffectSeverityQuestion: some View {
        ReflectCard {
            Text("How noticeable were your side effects?")
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

    private var reflectSideEffectsTagsQuestion: some View {
        ReflectCard {
            Text("What side effects showed up, if any?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(availableSideEffects, id: \.self) { effect in
                    ZStack(alignment: .topTrailing) {
                        Button(action: {
                            HapticManager.shared.lightImpact()
                            if sideEffectTags.contains(effect) {
                                sideEffectTags.remove(effect)
                            } else {
                                sideEffectTags.insert(effect)
                            }
                        }) {
                            Text(effect)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(sideEffectTags.contains(effect) ? Color(hex: "#2C332D") : Color(hex: "#E8E8E0"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(sideEffectTags.contains(effect) ? Color(hex: "#E8E8E0") : Color.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(sideEffectTags.contains(effect) ? 0.2 : 0.12), lineWidth: 1)
                                        )
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .buttonStyle(ScaleButtonStyle())

                        if isEditingCustomSideEffects && isCustomSideEffect(effect) {
                            Button(action: {
                                HapticManager.shared.lightImpact()
                                userSettings.removeCustomSideEffect(effect)
                                sideEffectTags.remove(effect)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .background(Color.black.opacity(0.35).clipShape(Circle()))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: {
                    showingAddCustomSideEffect = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Add custom")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#F5F5F5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: {
                    isEditingCustomSideEffects.toggle()
                }) {
                    Text(isEditingCustomSideEffects ? "Done" : "Edit")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(userSettings.customSideEffects.isEmpty && !isEditingCustomSideEffects)
            }
        }
    }

    private var reflectNotesQuestion: some View {
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

    private var reflectNavigationButtons: some View {
        HStack(spacing: 12) {
            if clampedReflectStepIndex > 0 {
                Button {
                    HapticManager.shared.lightImpact()
                    goToPreviousReflectStep()
                } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            Spacer()

            Button {
                HapticManager.shared.lightImpact()
                if isLastReflectStep {
                    presentReflectionSummary()
                } else {
                    goToNextReflectStep()
                }
            } label: {
                Text(isLastReflectStep ? "See Reflection & Log" : "Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#2C332D"))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(hex: "#E8E8E0"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canAdvanceReflectStep)
            .opacity(canAdvanceReflectStep ? 1 : 0.45)
        }
    }

    private var reflectionSummaryOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Upon Reflection")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))

                if isGeneratingReflectionSummary {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(Color(hex: "#E8E8E0"))
                        Text("Generating summary...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                } else if let reflectionSummaryError {
                    Text(reflectionSummaryError)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#F3D6D6"))
                } else {
                    Text(reflectionSummaryText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingReflectionSummary = false
                    } label: {
                        Text("Edit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        HapticManager.shared.successNotification()
                        processDoseAction(skipped: false)
                    } label: {
                        Text("Save Reflection")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#2C332D"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "#E8E8E0"))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isGeneratingReflectionSummary)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "#3B433C"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)
        }
    }

    private func presentReflectionSummary() {
        showingReflectionSummary = true
        isGeneratingReflectionSummary = true
        reflectionSummaryText = ""
        reflectionSummaryError = nil

        let trimmedNotes = logNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let focusValue = medicationToLog.medicationType == .stimulant && focusRating > 0 ? focusRating : nil
        let feelingValue = feelingRating > 0 ? feelingRating : nil
        let sideEffectValue = sideEffectSeverity > 0 ? sideEffectSeverity : nil
        let sideEffects = sideEffectTags.sorted()

        Task {
            do {
                let summary = try await OpenAIService.shared.summarizeDailyReflection(
                    medicationName: medicationToLog.name,
                    date: checkInDate,
                    feeling: feelingValue,
                    focus: focusValue,
                    emotionalTone: emotionalTone?.label,
                    sideEffectSeverity: sideEffectValue,
                    sideEffects: sideEffects,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
                await MainActor.run {
                    reflectionSummaryText = summary
                    isGeneratingReflectionSummary = false
                }
            } catch {
                await MainActor.run {
                    reflectionSummaryError = error.localizedDescription
                    isGeneratingReflectionSummary = false
                }
            }
        }
    }

    private func goToNextReflectStep() {
        guard currentReflectStepIndex < reflectSteps.count - 1 else { return }
        reflectStepAnimationDirection = .forward
        withAnimation(.easeInOut(duration: 0.25)) {
            currentReflectStepIndex += 1
        }
    }

    private func goToPreviousReflectStep() {
        guard currentReflectStepIndex > 0 else { return }
        reflectStepAnimationDirection = .backward
        withAnimation(.easeInOut(duration: 0.25)) {
            currentReflectStepIndex -= 1
        }
    }

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

    private func reflectSummaryRow(title: String, value: String) -> some View {
        let isUnset = value == "Not set"
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isUnset ? Color(hex: "#C7C7BD").opacity(0.6) : Color(hex: "#E8E8E0"))
            Spacer()
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
            timeToUse = checkInDate
        } else {
            timeToUse = selectedQuickTime == .custom ? actualTimeTaken : Date().addingTimeInterval(selectedQuickTime.timeOffset)
        }
        
        // Combine notes with mood and side effects
        var combinedNotes = logNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDailyCheckIn, let emotionalTone {
            let moodText = "Mood: \(emotionalTone.label)"
            if combinedNotes.isEmpty {
                combinedNotes = moodText
            } else {
                combinedNotes += "\n\n" + moodText
            }
        }

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
        let reflectionSummaryToSave: String? = {
            guard isDailyCheckIn else { return nil }
            let trimmed = reflectionSummaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        
	        if skipped {
	            if let action = store.skipMedication(
	                medication: medicationToLog,
	                actualTime: timeToUse,
	                notes: notesToSave,
	                reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil,
	                feelingRating: feelingToSave,
	                focusRating: focusToSave,
	                sideEffectSeverity: sideEffectToSave,
                    reflectionSummary: reflectionSummaryToSave,
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
                    reflectionSummary: reflectionSummaryToSave,
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
        if let mood = noteParts.mood?.lowercased(),
           let tone = EmotionalTone(rawValue: mood) {
            emotionalTone = tone
        } else {
            emotionalTone = nil
        }

        didLoadExistingCheckIn = true
    }

    private func splitNotesAndSideEffects(from notes: String?) -> (notes: String?, checkInNotes: String?, sideEffectsList: [String], mood: String?) {
        guard var raw = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (nil, nil, [], nil)
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
            sideEffectsList,
            moodValue?.isEmpty == true ? nil : moodValue
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
            HStack(spacing: 8) {
                Text(lowLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))

                Spacer()

                Text(highLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }
            
            HStack(spacing: 8) {
                ForEach(range, id: \.self) { index in
                    Button(action: {
                        HapticManager.shared.strongImpact()
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
