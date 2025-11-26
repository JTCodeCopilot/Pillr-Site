//
//  AddMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI
import UserNotifications

struct AddMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    var onAdd: () -> Void
    var onProgressStateChange: (Bool) -> Void = { _ in }

    // Core fields
    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var dosageUnit: String = "mg"
    @State private var iconName: String = "pill"

    // Schedule / reminders
    @State private var frequency: String = "As needed"
    @State private var timeToTake: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var reminderTimes: [Date] = []
    @State private var enableNotification: Bool = true
    @State private var isOneTimeWithFollowUp: Bool = false

    // Notes
    @State private var notes: String = ""

    // Inventory
    @State private var pillCountString: String = ""
    @State private var pillsPerDoseString: String = "1"
    @State private var refillThresholdString: String = ""
    @State private var trackPillCount: Bool = false

    // ADHD / stimulant specific
    @State private var isADHDMedication: Bool = false
    @State private var medicationType: MedicationType = .other
    @State private var isExtendedRelease: Bool = false
    @State private var onsetMinutesString: String = ""
    @State private var durationMinutesString: String = ""
    @State private var enableDailyCheckIn: Bool = false
    @State private var enableStimulantPhaseNotifications: Bool = false
    @State private var useCustomDailyCheckInTime: Bool = false
    @State private var customDailyCheckInTime: Date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var onsetMinutesError: String? = nil
    @State private var durationMinutesError: String? = nil

    // AI search / premium
    @State private var showingAISearch: Bool = false
    @State private var showingPremiumUpgrade: Bool = false

    // Keyboard / focus
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?

    // Validation
    @State private var showValidationErrors: Bool = false
    @State private var nameError: String? = nil
    @State private var dosageError: String? = nil
    @State private var pillCountError: String? = nil
    @State private var refillThresholdError: String? = nil

    // Multi-step flow
    enum AddMedicationStep: Int, CaseIterable {
        case basics
        case schedule
        case trackingAndADHD
        case notesAndReview
    }

    @State private var currentStep: AddMedicationStep = .basics

    enum Field: Hashable {
        case name, dosage, frequency, notes, pillCount, pillsPerDose, refillThreshold, onsetMinutes, durationMinutes
    }

    private let standardFieldHeight: CGFloat = 52
    private let actionButtonMinWidth: CGFloat = 58

    private enum ScrollAnchor {
        static let bottom = "AddMedicationViewBottomAnchor"
    }

    let frequencies = ["Once daily", "Twice daily", "Three times daily", "As needed"]
    let dosageUnits = ["mg", "ml", "tablets", "capsules", "custom"]
    @State private var customUnit: String = ""
    @State private var isCustomUnitSelected: Bool = false

    private var contentExpansionKey: ContentExpansionKey {
            ContentExpansionKey(
                step: currentStep,
                customUnitVisible: isCustomUnitSelected,
                frequency: frequency,
                reminderCount: reminderTimes.count,
                trackPillCount: trackPillCount,
                isADHDMedication: isADHDMedication,
                medicationType: medicationType,
                isExtendedRelease: isExtendedRelease,
                enableDailyCheckIn: enableDailyCheckIn,
                useCustomDailyCheckInTime: useCustomDailyCheckInTime,
                needsMultipleReminders: needsMultipleReminders,
                isOneTimeWithFollowUp: isOneTimeWithFollowUp
            )
    }

    // MARK: - Body

    var body: some View {
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

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        header
                        stepProgressView

                        if currentStep != .basics {
                            VStack(spacing: 12) {
                                summarySection
                                Divider()
                                    .frame(height: 1)
                                    .background(Color(hex: "#C7C7BD").opacity(0.3))
                            }
                        }

                        Group {
                            switch currentStep {
                            case .basics:
                                basicsSection
                            case .schedule:
                                scheduleSection
                            case .trackingAndADHD:
                                trackingAndADHDSection
                            case .notesAndReview:
                                notesAndReviewSection
                            }
                        }

                        navigationFooter
                            .id(ScrollAnchor.bottom)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 0, for: .scrollContent)
                .onChange(of: focusedField) { _, field in
                    if let field = field {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
                .onChange(of: contentExpansionKey) { _ in
                    scrollToBottom(using: scrollProxy)
                }
            }
            .onAppear {
                // Always start from a fresh form and step 1
                resetForm()
                setupKeyboardObservers()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    focusedField = .name
                }
            }
            .onChange(of: currentStep) { newStep in
                onProgressStateChange(newStep != .basics)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Button(action: {
                        triggerStrongHaptic()
                        moveToPreviousField()
                    }) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    .disabled(!canMoveToPreviousField)

                    Button(action: {
                        triggerStrongHaptic()
                        moveToNextField()
                    }) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    .disabled(!canMoveToNextField)

                    Spacer()

                    Button(action: {
                        triggerStrongHaptic()
                        focusedField = nil
                    }) {
                        Text("Done")
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
        }
        .sheet(isPresented: $showingAISearch) {
            NavigationView {
                AISearchMedicationView(onSelectMedication: { result in
                    // Preserve AI name
                    name = result.name

                    // Infer dosage unit from commonDosage
                    if let dosageStr = result.commonDosage {
                        if dosageStr.contains("mg") {
                            dosageUnit = "mg"
                        } else if dosageStr.contains("ml") {
                            dosageUnit = "ml"
                        } else if dosageStr.contains("tablet") {
                            dosageUnit = "tablets"
                        } else if dosageStr.contains("capsule") {
                            dosageUnit = "capsules"
                        }
                    }

                    // Pre-populate ADHD timing when we have guidelines
                    if let guideline = ADHDMedicationGuidelines.guideline(for: result.name) {
                        isADHDMedication = true
                        medicationType = guideline.medicationType
                        isExtendedRelease = guideline.isExtendedRelease
                        onsetMinutesString = "\(guideline.typicalOnsetMinutes)"
                        durationMinutesString = "\(guideline.typicalDurationMinutes)"
                        if guideline.medicationType == .stimulant {
                            enableDailyCheckIn = true
                        }
                    }

                    // Seed notes with description / need-to-know
                    var notesText = ""
                    if !result.description.isEmpty {
                        notesText = result.description
                    }
                    if let needToKnow = result.needToKnow, !needToKnow.isEmpty {
                        if !notesText.isEmpty { notesText += "\n\n" }
                        notesText += "NEED TO KNOW: \(needToKnow)"
                    }
                    notes = notesText
                })
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(StoreManager.shared)
        }
    }

    // MARK: - Top-level sections

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add Medication")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#E8E8E0"))

            Text("Step \(currentStep.rawValue + 1) of \(AddMedicationStep.allCases.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
        }
        // Add a touch more leading padding so the title
        // doesn't feel tight against the screen edge
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var stepProgressView: some View {
        ProgressView(
            value: Double(currentStep.rawValue + 1),
            total: Double(AddMedicationStep.allCases.count)
        )
        .tint(Color(hex: "#C7C7BD"))
        .scaleEffect(x: 1, y: 1.6, anchor: .center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var basicsSection: some View {
        FormSection(title: "MEDICATION INFO", icon: "pills.fill") {
            VStack(spacing: 12) {
                // Name + AI search
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .bottom, spacing: 10) {
                        enhancedInputField(
                            title: "Medication Name",
                            placeholder: "e.g., Vyvanse, Ritalin",
                            text: $name,
                            field: .name,
                            isRequired: true,
                            errorMessage: nameError
                        )
                        .id(Field.name)

                        Button(action: {
                            triggerStrongHaptic()
                            if userSettings.isPremiumUser {
                                showingAISearch = true
                            } else {
                                showingPremiumUpgrade = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))

                                if !userSettings.isPremiumUser {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "#D4A017"))
                                }
                            }
                            .foregroundColor(Color(hex: "#E8E8E0"))
                            .padding(.horizontal, 10)
                            .frame(minWidth: actionButtonMinWidth)
                            .frame(height: standardFieldHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                // Dosage + unit
                HStack(spacing: 10) {
                    enhancedInputField(
                        title: "Dosage",
                        placeholder: dosageUnit == "ml" ? "10" : "50",
                        text: $dosage,
                        field: .dosage,
                        iconName: nil,
                        isRequired: true,
                        errorMessage: dosageError,
                        keyboardType: .decimalPad
                    )
                    .id(Field.dosage)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Menu {
                            ForEach(dosageUnits, id: \.self) { unit in
                                Button {
                                    triggerStrongHaptic()
                                    dosageUnit = unit
                                    isCustomUnitSelected = unit == "custom"
                                } label: {
                                    Text(unit)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(dosageUnit)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            }
                            .padding(.horizontal, 10)
                            .frame(minWidth: 90, minHeight: standardFieldHeight)
                            .frame(height: standardFieldHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .frame(minWidth: 100)
                }

                if isCustomUnitSelected {
                enhancedInputField(
                    title: "Custom Unit Type",
                    placeholder: "e.g. drops, sprays",
                    text: $customUnit,
                    field: nil,
                    iconName: nil,
                    isRequired: true,
                    errorMessage: customUnit.isEmpty && showValidationErrors ? "Custom unit type is required" : nil
                )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        FormSection(title: "SCHEDULE", icon: "calendar.badge.clock") {
            VStack(spacing: 12) {
                // Frequency picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("How Often You’ll Take It")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))

                    Menu {
                        ForEach(frequencies, id: \.self) { freq in
                            Button(action: {
                                frequency = freq
                                setupReminderTimesForFrequency(freq)
                                if enableNotification {
                                    requestNotificationPermissionIfNeeded()
                                }
                            }) {
                                Text(freq)
                            }
                        }
                    } label: {
                        HStack {
                            Text(frequency)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: standardFieldHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }

                // Time pickers
                if needsMultipleReminders {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reminder Times")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))

                            ForEach(0..<reminderTimes.count, id: \.self) { index in
                            TimePickerRow(
                                title: "Dose \(index + 1)",
                                time: $reminderTimes[index]
                            )
                        }
                    }
                } else if frequency != "As needed" {
                    TimePickerRow(
                        title: "Reminder Time",
                        time: $timeToTake
                    )
                }
            }
        }

        if frequency != "As needed" {
            FormSection(title: "NOTIFICATIONS", icon: "bell.fill") {
                VStack(spacing: 12) {
                    if needsMultipleReminders || frequency == "Once daily" {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $isOneTimeWithFollowUp.animation(.easeInOut)) {
                                VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("One-time with Follow-up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                if !userSettings.isPremiumUser {
                                    Button(action: {
                                        triggerStrongHaptic()
                                        showingPremiumUpgrade = true
                                    }) {
                                        Text("PREMIUM")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "#D4A017"))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                                    Text(userSettings.isPremiumUser ?
                                         "Single reminder + 30-min follow-up if not taken" :
                                            "Follow-up reminders require premium subscription")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                            .disabled(!userSettings.isPremiumUser)
                            .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                            .onChange(of: isOneTimeWithFollowUp) { _ in
                                triggerStrongHaptic()
                            }
                        }
                    }
                }
            }
        }

        focusAndTimingSection
    }

    @ViewBuilder
    private var focusAndTimingSection: some View {
        FormSection(title: nil, icon: "hourglass") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Is This an ADHD Medication?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))

                    Picker("ADHD medication", selection: $isADHDMedication) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                if isADHDMedication {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What kind of ADHD medication?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Picker("Medication type", selection: $medicationType) {
                            Text("Stimulant").tag(MedicationType.stimulant)
                            Text("Non-stimulant").tag(MedicationType.nonStimulant)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if isADHDMedication && medicationType == .stimulant {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $isExtendedRelease) {
                            Text("Extended-release formulation")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                        .onChange(of: isExtendedRelease) { _ in
                            triggerStrongHaptic()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(isOn: $enableStimulantPhaseNotifications) {
                                Text("Turn on focus window")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                    .padding(.trailing, 12)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                            .onChange(of: enableStimulantPhaseNotifications) { enabled in
                                if !enabled {
                                    onsetMinutesString = ""
                                    durationMinutesString = ""
                                    onsetMinutesError = nil
                                    durationMinutesError = nil
                                    enableDailyCheckIn = false
                                    useCustomDailyCheckInTime = false
                                }
                            }

                            Text("Use these times to map your focus sessions. Pillr uses the start and wear-off windows to help you plan when you’ll be at your sharpest and when to ease into breaks.")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.leading, 6)
                        }

                        if enableStimulantPhaseNotifications {
                            enhancedInputField(
                                title: "Starts working after (minutes)",
                                placeholder: "30",
                                text: $onsetMinutesString,
                                field: .onsetMinutes,
                                isRequired: true,
                                errorMessage: onsetMinutesError,
                                keyboardType: .numberPad
                            )

                            enhancedInputField(
                                title: "Lasts about (minutes)",
                                placeholder: "240",
                                text: $durationMinutesString,
                                field: .durationMinutes,
                                isRequired: true,
                                errorMessage: durationMinutesError,
                                keyboardType: .numberPad
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle(isOn: $enableDailyCheckIn) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Daily check-in")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                        Text("At the end of the wear-off window, Pillr will remind you to log focus and side effects for this medication.")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                    }
                                    .padding(.trailing, 12)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                .onChange(of: enableDailyCheckIn) { newValue in
                                    triggerStrongHaptic()
                                    if !newValue {
                                        useCustomDailyCheckInTime = false
                                    }
                                }

                                if enableDailyCheckIn {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Default reminder arrives ~10 minutes before the medication wears off. Prefer a different time? Pick one below.")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))

                                        Toggle(isOn: $useCustomDailyCheckInTime) {
                                            Text("Choose a custom check-in time")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                        }
                                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                        .onChange(of: useCustomDailyCheckInTime) { _ in
                                            triggerStrongHaptic()
                                        }

                                        if useCustomDailyCheckInTime {
                                            TimePickerRow(title: "Check-in time", time: $customDailyCheckInTime)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: isADHDMedication) { newValue in
            triggerStrongHaptic()
            if newValue {
                if medicationType == .other {
                    medicationType = .stimulant
                }
            } else {
                medicationType = .other
                isExtendedRelease = false
                onsetMinutesString = ""
                durationMinutesString = ""
                onsetMinutesError = nil
                durationMinutesError = nil
                enableStimulantPhaseNotifications = false
                if enableDailyCheckIn {
                    useCustomDailyCheckInTime = true
                }
            }
        }
        .onChange(of: medicationType) { newType in
            triggerStrongHaptic()
            if newType != .stimulant {
                isExtendedRelease = false
                onsetMinutesString = ""
                durationMinutesString = ""
                onsetMinutesError = nil
                durationMinutesError = nil
                enableStimulantPhaseNotifications = false
                if enableDailyCheckIn {
                    useCustomDailyCheckInTime = true
                }
            } else {
                _ = validateADHDFields()
            }
        }
    }

    @ViewBuilder
    private var trackingAndADHDSection: some View {
        VStack(spacing: 16) {
            if medicationType != .stimulant {
                FormSection(title: "DAILY CHECK-IN", icon: "calendar.badge.clock") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $enableDailyCheckIn) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily wellness check-in")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                Text("Pick a time for a gentle reminder to jot anything you'd like to remember about this medication.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                        .onChange(of: enableDailyCheckIn) { newValue in
                            triggerStrongHaptic()
                            if newValue {
                                useCustomDailyCheckInTime = true
                            }
                        }

                        if enableDailyCheckIn {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose when you'd like to reflect each day.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                                TimePickerRow(title: "Check-in time", time: $customDailyCheckInTime)
                            }
                        }
                    }
                }
            }

            FormSection(title: "INVENTORY", icon: "archivebox.fill") {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $trackPillCount.animation(.easeInOut)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Track Pill Count")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    if !userSettings.isPremiumUser {
                                        Button(action: {
                                            triggerStrongHaptic()
                                            showingPremiumUpgrade = true
                                        }) {
                                            Text("PREMIUM")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "#D4A017"))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                Text(userSettings.isPremiumUser ?
                                     "Get refill reminders and track usage" :
                                        "Inventory tracking requires premium subscription")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                        .disabled(!userSettings.isPremiumUser)
                        .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                        .onChange(of: trackPillCount) { newValue in
                            triggerStrongHaptic()
                            if !newValue {
                                pillCountError = nil
                                refillThresholdError = nil
                            }
                        }
                    }

                    if trackPillCount {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                enhancedInputField(
                                    title: "Total Pills",
                                    placeholder: "30",
                                    text: $pillCountString,
                                    field: .pillCount,
                                    isRequired: true,
                                    errorMessage: pillCountError,
                                    keyboardType: .numberPad
                                )
                                .id(Field.pillCount)

                                enhancedInputField(
                                    title: "Per Dose",
                                    placeholder: "1",
                                    text: $pillsPerDoseString,
                                    field: .pillsPerDose,
                                    keyboardType: .numberPad
                                )
                                .id(Field.pillsPerDose)
                            }

                            enhancedInputField(
                                title: "Refill Reminder",
                                placeholder: "5",
                                text: $refillThresholdString,
                                field: .refillThreshold,
                                isRequired: true,
                                errorMessage: refillThresholdError,
                                keyboardType: .numberPad
                            )
                            .id(Field.refillThreshold)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var notesAndReviewSection: some View {
        FormSection(title: "NOTES", icon: "note.text.fill") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Information")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                        )
                        .frame(minHeight: 100)

                    TextEditor(text: $notes)
                        .focused($focusedField, equals: .notes)
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(12)

                    if notes.isEmpty {
                        Text("e.g., Take with food, side effects to watch for...")
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .allowsHitTesting(false)
                    }
                }
            }
            .id(Field.notes)
        }
    }

    @ViewBuilder
    private var navigationFooter: some View {
        VStack(spacing: 12) {
            HStack {
                if currentStep != .basics {
                    Button(action: {
                        triggerStrongHaptic()
                        goToPreviousStep()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.2))
                        )
                    }
                }

                Spacer()

                Button(action: {
                    triggerStrongHaptic()
                    if currentStep == .notesAndReview {
                        if validateForm() {
                            saveMedication()
                        } else {
                            showValidationErrors = true
                            HapticManager.shared.errorNotification()
                        }
                    } else {
                        goToNextStep()
                    }
                }) {
                    HStack {
                        if currentStep == .notesAndReview {
                            Text("Add Medication")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        } else {
                            Text("Next")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(
                        currentStep == .notesAndReview && !isFormValid
                        ? Color.white
                        : Color(hex: "#404C42")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                currentStep == .notesAndReview && !isFormValid
                                ? Color.gray.opacity(0.6)
                                : Color(hex: "#C7C7BD")
                            )
                    )
                }
                .accessibilityLabel(currentStep == .notesAndReview ? "Add medication" : "Next step")
            }

            if currentStep == .notesAndReview && showValidationErrors && !isFormValid {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                    Text("Please fill in all required fields")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OVERVIEW")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                .tracking(0.5)
            summaryCard
        }
    }

    private var summaryCard: some View {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayUnit = dosageUnit == "custom" && !customUnit.isEmpty ? customUnit : dosageUnit
        let trimmedFrequency = frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPillCount = pillCountString.trimmingCharacters(in: .whitespacesAndNewlines)

        let adhdDescription: String? = {
            guard isADHDMedication else { return nil }
            if medicationType == .stimulant {
                return isExtendedRelease ? "Yes (Stimulant, XR)" : "Yes (Stimulant)"
            } else {
                return "Yes"
            }
        }()

        let pillInventoryValue: String = {
            guard trackPillCount && userSettings.isPremiumUser else { return "No" }
            return trimmedPillCount.isEmpty ? "Yes (total not set)" : "Yes (\(trimmedPillCount) total)"
        }()

        return VStack(alignment: .leading, spacing: 14) {
            summaryRow(
                title: "Medication name",
                value: trimmedName.isEmpty ? "Not set" : trimmedName
            )

            summaryRow(
                title: "Amount",
                value: trimmedDosage.isEmpty ? "Not set" : "\(trimmedDosage) \(displayUnit)"
            )

            summaryRow(
                title: "Notifications",
                value: trimmedFrequency.isEmpty ? "Not set" : trimmedFrequency
            )

            if let adhdDescription {
                summaryRow(title: "ADHD medication", value: adhdDescription)
            }

            summaryRow(
                title: "Daily check-in",
                value: enableDailyCheckIn ? "Yes" : "No"
            )

            summaryRow(title: "Pill inventory", value: pillInventoryValue)
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

    private func summaryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
        }
    }

    @ViewBuilder
    private func FormSection<Content: View>(
        title: String? = nil,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let _ = icon
            if let title = title, !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        .tracking(0.5)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private func enhancedInputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field?,
        iconName: String? = nil,
        isRequired: Bool = false,
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .bold))
                }
            }

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .focused($focusedField, equals: field)
                .submitLabel(getSubmitLabel(for: field))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
                .padding(.horizontal, 16)
                .frame(height: standardFieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    focusedField == field
                                    ? Color(hex: "#C7C7BD")
                                    : (showValidationErrors && errorMessage != nil
                                       ? Color.red
                                       : Color(hex: "#C7C7BD").opacity(0.3)),
                                    lineWidth: focusedField == field ? 2 : 1
                                )
                        )
                )
                .onSubmit {
                    handleFieldSubmit(field)
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    var processedValue = newValue

                    if field == .dosage || field == .onsetMinutes || field == .durationMinutes {
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            processedValue = filtered
                            text.wrappedValue = filtered
                        }
                    }

                    validateField(field, value: processedValue)
                }

            if let errorMessage = errorMessage, showValidationErrors {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Helper Functions

    private func goToNextStep() {
        switch currentStep {
        case .basics:
            guard validateBasicsStep() else {
                HapticManager.shared.errorNotification()
                return
            }
            currentStep = .schedule
            focusedField = nil
        case .schedule:
            currentStep = .trackingAndADHD
            focusedField = nil
        case .trackingAndADHD:
            if !validateInventoryFields() {
                showValidationErrors = true
                HapticManager.shared.errorNotification()
                return
            }
            if !validateADHDFields() {
                showValidationErrors = true
                HapticManager.shared.errorNotification()
                return
            }
            showValidationErrors = false
            currentStep = .notesAndReview
            focusedField = nil
        case .notesAndReview:
            break
        }
    }

    private func goToPreviousStep() {
        switch currentStep {
        case .basics:
            break
        case .schedule:
            currentStep = .basics
        case .trackingAndADHD:
            currentStep = .schedule
        case .notesAndReview:
            currentStep = .trackingAndADHD
        }
        focusedField = nil
    }

    private func getSubmitLabel(for field: Field?) -> SubmitLabel {
        switch field {
        case .name, .dosage: return .next
        case .pillCount, .pillsPerDose: return .next
        case .onsetMinutes: return .next
        case .durationMinutes: return .done
        default: return .done
        }
    }

    private func handleFieldSubmit(_ field: Field?) {
        switch field {
        case .name: focusedField = .dosage
        case .dosage: focusedField = nil
        case .notes:
            if trackPillCount { focusedField = .pillCount }
            else { focusedField = nil }
        case .pillCount: focusedField = .pillsPerDose
        case .pillsPerDose: focusedField = .refillThreshold
        case .onsetMinutes: focusedField = .durationMinutes
        case .durationMinutes: focusedField = nil
        default: focusedField = nil
        }
    }

    private func validateField(_ field: Field?, value: String) {
        switch field {
        case .name:
            nameError = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Medication name is required" : nil
        case .dosage:
            dosageError = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Dosage is required" : nil
        case .pillCount:
            if trackPillCount && userSettings.isPremiumUser {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    pillCountError = "Total pills is required"
                } else if let count = Int(trimmed), count > 0 {
                    pillCountError = nil
                } else {
                    pillCountError = "Enter a valid number"
                }
            } else {
                pillCountError = nil
            }
        case .refillThreshold:
            if trackPillCount && userSettings.isPremiumUser {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    refillThresholdError = "Refill reminder is required"
                } else if let days = Int(trimmed), days > 0 {
                    refillThresholdError = nil
                } else {
                    refillThresholdError = "Enter a valid number"
                }
            } else {
                refillThresholdError = nil
            }
        case .onsetMinutes:
            guard isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications else {
                onsetMinutesError = nil
                return
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                onsetMinutesError = "Onset time is required"
            } else if let minutes = Int(trimmed), minutes > 0 {
                onsetMinutesError = nil
            } else {
                onsetMinutesError = "Enter a valid number"
            }
        case .durationMinutes:
            guard isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications else {
                durationMinutesError = nil
                return
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                durationMinutesError = "Wear-off time is required"
            } else if let minutes = Int(trimmed), minutes > 0 {
                durationMinutesError = nil
            } else {
                durationMinutesError = "Enter a valid number"
            }
        default:
            break
        }
    }

    private func validateForm() -> Bool {
        validateField(.name, value: name)
        validateField(.dosage, value: dosage)
        if isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications {
            validateField(.onsetMinutes, value: onsetMinutesString)
            validateField(.durationMinutes, value: durationMinutesString)
        }
        return isFormValid
    }

    private func validateInventoryFields() -> Bool {
        guard trackPillCount && userSettings.isPremiumUser else {
            pillCountError = nil
            refillThresholdError = nil
            return true
        }

        validateField(.pillCount, value: pillCountString)
        validateField(.refillThreshold, value: refillThresholdString)

        return pillCountError == nil && refillThresholdError == nil
    }

    private func validateADHDFields() -> Bool {
        guard isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications else {
            onsetMinutesError = nil
            durationMinutesError = nil
            return true
        }

        validateField(.onsetMinutes, value: onsetMinutesString)
        validateField(.durationMinutes, value: durationMinutesString)

        return onsetMinutesError == nil && durationMinutesError == nil
    }

    private func validateBasicsStep() -> Bool {
        validateField(.name, value: name)
        validateField(.dosage, value: dosage)

        let customUnitValid = dosageUnit != "custom" || !customUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let valid = nameError == nil && dosageError == nil && customUnitValid

        showValidationErrors = !valid
        return valid
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
        }
    }

    private var needsMultipleReminders: Bool {
        switch frequency {
        case "Twice daily", "Three times daily":
            return true
        default:
            return false
        }
    }

    private var canMoveToPreviousField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name: return false
        case .dosage, .frequency, .notes, .pillCount, .pillsPerDose, .refillThreshold: return true
        case .durationMinutes: return true
        case .onsetMinutes: return false
        }
    }

    private var canMoveToNextField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name, .dosage, .frequency: return true
        case .notes: return trackPillCount
        case .pillCount, .pillsPerDose: return trackPillCount
        case .refillThreshold: return false
        case .onsetMinutes: return true
        case .durationMinutes: return false
        }
    }

    private func moveToPreviousField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: break
        case .dosage: focusedField = .name
        case .frequency: focusedField = .dosage
        case .notes: focusedField = .frequency
        case .pillCount: focusedField = .notes
        case .pillsPerDose: focusedField = .pillCount
        case .refillThreshold: focusedField = .pillsPerDose
        case .durationMinutes: focusedField = .onsetMinutes
        case .onsetMinutes: focusedField = nil
        }
    }

    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: focusedField = .dosage
        case .dosage: focusedField = .frequency
        case .frequency: focusedField = nil
        case .notes:
            if trackPillCount { focusedField = .pillCount }
            else { focusedField = nil }
        case .pillCount: focusedField = .pillsPerDose
        case .pillsPerDose: focusedField = .refillThreshold
        case .refillThreshold: focusedField = nil
        case .onsetMinutes: focusedField = .durationMinutes
        case .durationMinutes: focusedField = nil
        }
    }

    private func triggerStrongHaptic() {
        HapticManager.shared.pulseRigid()
    }

    private func setupReminderTimesForFrequency(_ frequency: String) {
        let calendar = Calendar.current

        switch frequency {
        case "Twice daily":
            let morningTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            let eveningTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
            reminderTimes = [morningTime, eveningTime]
            enableNotification = true

        case "Three times daily":
            let morningTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            let middayTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date()
            let eveningTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
            reminderTimes = [morningTime, middayTime, eveningTime]
            enableNotification = true

        case "As needed":
            reminderTimes = []
            enableNotification = false

        default:
            reminderTimes = []
            enableNotification = true
        }
    }

    private var isFormValid: Bool {
        let basicValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !frequency.isEmpty

        let customUnitValid = dosageUnit != "custom" || (dosageUnit == "custom" && !customUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if needsMultipleReminders && reminderTimes.isEmpty {
            return false
        }

        if trackPillCount && userSettings.isPremiumUser {
            let trimmedPillCount = pillCountString.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPillsPerDose = pillsPerDoseString.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRefillThreshold = refillThresholdString.trimmingCharacters(in: .whitespacesAndNewlines)
            let pillCountValue = Int(trimmedPillCount) ?? 0
            let pillsPerDoseValue = Int(trimmedPillsPerDose) ?? 0
            let refillThresholdValue = Int(trimmedRefillThreshold) ?? 0
            let pillCountValid = !trimmedPillCount.isEmpty && pillCountValue > 0
            let pillsPerDoseValid = !trimmedPillsPerDose.isEmpty && pillsPerDoseValue > 0
            let refillThresholdValid = !trimmedRefillThreshold.isEmpty && refillThresholdValue > 0
            return basicValid && pillCountValid && pillsPerDoseValid && refillThresholdValid && customUnitValid
        }

        if isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications {
            let trimmedOnset = onsetMinutesString.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDuration = durationMinutesString.trimmingCharacters(in: .whitespacesAndNewlines)
            let onsetValid = !trimmedOnset.isEmpty && (Int(trimmedOnset) ?? 0) > 0
            let durationValid = !trimmedDuration.isEmpty && (Int(trimmedDuration) ?? 0) > 0
            return basicValid && customUnitValid && onsetValid && durationValid
        }

        return basicValid && customUnitValid
    }

    private func resetForm() {
        name = ""
        dosage = ""
        dosageUnit = "mg"
        iconName = "pill"
        currentStep = .basics
        frequency = "As needed"
        timeToTake = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        reminderTimes = []
        notes = ""
        enableNotification = true
        pillCountString = ""
        pillsPerDoseString = "1"
        refillThresholdString = ""
        trackPillCount = false
        isOneTimeWithFollowUp = false
        isADHDMedication = false
        medicationType = .other
        isExtendedRelease = false
        onsetMinutesString = ""
        durationMinutesString = ""
        enableDailyCheckIn = false
        enableStimulantPhaseNotifications = false
        useCustomDailyCheckInTime = false
        customDailyCheckInTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
        onsetMinutesError = nil
        durationMinutesError = nil
        showingAISearch = false
        showingPremiumUpgrade = false
        keyboardHeight = 0
        focusedField = nil
        showValidationErrors = false
        nameError = nil
        dosageError = nil
        pillCountError = nil
        refillThresholdError = nil
        customUnit = ""
        isCustomUnitSelected = false
        onProgressStateChange(false)
    }

    private func saveMedication() {
        let pillCount = trackPillCount ? Int(pillCountString) : nil
        let pillsPerDose = trackPillCount ? (Int(pillsPerDoseString) ?? 1) : 1
        let refillThreshold = trackPillCount && !refillThresholdString.isEmpty ? Int(refillThresholdString) : nil

        let finalDosageUnit = dosageUnit == "custom" && !customUnit.isEmpty ? customUnit : dosageUnit

        let hasFocusWindow = isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications
        let supportsGeneralCheckIn = medicationType != .stimulant
        let onsetMinutes = hasFocusWindow ? Int(onsetMinutesString) : nil
        let durationMinutes = hasFocusWindow ? Int(durationMinutesString) : nil
        let shouldEnableDailyCheckIn = enableDailyCheckIn && (hasFocusWindow || supportsGeneralCheckIn)
        let shouldUseCustomCheckInTime = supportsGeneralCheckIn || useCustomDailyCheckInTime
        let selectedDailyCheckInTime = (shouldEnableDailyCheckIn && shouldUseCustomCheckInTime) ? customDailyCheckInTime : nil

        let success = store.addMedication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            dosageUnit: finalDosageUnit,
            iconName: iconName,
            frequency: frequency,
            timeToTake: timeToTake,
            reminderTimes: (needsMultipleReminders && !isOneTimeWithFollowUp) ? reminderTimes : [],
            notes: {
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedNotes.isEmpty ? nil : trimmedNotes
            }(),
            enableNotification: enableNotification,
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp,
            medicationType: medicationType,
            isExtendedRelease: isExtendedRelease,
            onsetMinutes: onsetMinutes,
            durationMinutes: durationMinutes,
            enableDailyCheckIn: shouldEnableDailyCheckIn,
            enableStimulantPhaseNotifications: enableStimulantPhaseNotifications,
            dailyCheckInTime: selectedDailyCheckInTime
        )

        if success {
            onAdd()
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            self.enableNotification = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.enableNotification = false
                        }
                    }
                }
            } else if settings.authorizationStatus == .denied {
                DispatchQueue.main.async {
                    self.enableNotification = false
                }
            }
        }
    }

    private struct ContentExpansionKey: Hashable {
        let step: AddMedicationStep
        let customUnitVisible: Bool
        let frequency: String
        let reminderCount: Int
        let trackPillCount: Bool
        let isADHDMedication: Bool
        let medicationType: MedicationType
        let isExtendedRelease: Bool
        let enableDailyCheckIn: Bool
        let useCustomDailyCheckInTime: Bool
        let needsMultipleReminders: Bool
        let isOneTimeWithFollowUp: Bool
    }

}

// MARK: - Supporting Views

struct TimePickerRow: View {
    let title: String
    @Binding var time: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                Text(timeString(from: time))
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }

            Spacer()

            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(Color(hex: "#C7C7BD"))
                .onChange(of: time) { _ in
                    HapticManager.shared.pulseRigid()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Extensions

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}
