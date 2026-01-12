//
//  EditMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct EditMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var storeManager: StoreManager
    
    // Passed-in medication to edit
    var medication: Medication
    var onUpdate: () -> Void
    
    // State for editing
    @State private var name: String
    @State private var dosage: String
    @State private var dosageUnit: String
    @State private var iconName: String
    @State private var frequency: String
    @State private var timeToTake: Date
    @State private var reminderTimes: [Date] = []
    @State private var notes: String
    @State private var enableNotification: Bool
    @State private var pillCountString: String = ""
    @State private var pillsPerDoseString: String = "1"
    @State private var refillThresholdString: String = ""
    @State private var trackPillCount: Bool = false
    @State private var isOneTimeWithFollowUp: Bool = false
    // ADHD / stimulant specific fields
    @State private var isADHDMedication: Bool = false
    @State private var medicationType: MedicationType = .other
    @State private var isExtendedRelease: Bool = false
    @State private var onsetMinutesString: String = ""
    @State private var durationMinutesString: String = ""
    @State private var effectsGoneMinutesString: String = ""
    @State private var enableDailyCheckIn: Bool = false
    @State private var enableStimulantPhaseNotifications: Bool = false
    @State private var useCustomDailyCheckInTime: Bool = false
    @State private var customDailyCheckInTime: Date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingPremiumUpgrade: Bool = false
    @State private var showingFocusTimingGuidanceSheet: Bool = false
    @State private var focusTimingGuidanceMedicationName: String = ""
    @State private var focusTimingGuidance: FocusTimingGuidance? = nil
    @State private var focusTimingError: String? = nil
    @State private var isFocusTimingLoading: Bool = false
    @State private var customUnit: String = ""
    @State private var isCustomUnitSelected: Bool = false
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    // Form validation states
    @State private var showValidationErrors: Bool = false
    @State private var nameError: String? = nil
    @State private var dosageError: String? = nil
    @State private var pillCountError: String? = nil
    @State private var pillsPerDoseError: String? = nil
    @State private var refillThresholdError: String? = nil
    @State private var onsetMinutesError: String? = nil
    @State private var durationMinutesError: String? = nil
    @State private var effectsGoneMinutesError: String? = nil
    @State private var frequencyError: String? = nil
    @State private var scrollTargetField: Field? = nil

    enum Field {
        case name, dosage, frequency, notes, pillCount, pillsPerDose, refillThreshold, onsetMinutes, durationMinutes, effectsGoneMinutes
    }

    let frequencies = ["Once daily", "Twice daily", "Three times daily", "As needed"]
    let dosageUnits = ["mg", "ml", "tablets", "capsules", "custom"]
    private let standardFieldHeight: CGFloat = 52
    private let formSectionBackgroundColor = Color.white.opacity(0.06)
    private let timePickerHeight: CGFloat = 140
    private let focusOnsetRange: ClosedRange<Int> = 30...1440
    private let focusDurationRange: ClosedRange<Int> = 30...1440
    private let focusEffectsGoneRange: ClosedRange<Int> = 30...1440
    
    // Computed properties
    private var needsMultipleReminders: Bool {
        userSettings.isPremiumUser && isPremiumFrequency(frequency)
    }
    
    private var progressColor: (Int) -> Color {
        return { index in
            let completedSteps = completedFormSteps
            return index < completedSteps ? Color(hex: "#C7C7BD") : Color(hex: "#606A63")
        }
    }
    
    private var completedFormSteps: Int {
        var steps = 0
        if !name.isEmpty { steps += 1 }
        if !dosage.isEmpty { steps += 1 }
        if frequency != "As needed" || !notes.isEmpty { steps += 1 }
        if isFormValid { steps += 1 }
        return min(steps, 4)
    }
    
    // Initialize with the medication's existing values
    init(medication: Medication, onUpdate: @escaping () -> Void) {
        self.medication = medication
        self.onUpdate = onUpdate
        
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        
        // Check if medication uses a custom unit
        let standardUnits = ["mg", "ml", "tablets", "capsules"]
        if standardUnits.contains(medication.dosageUnit) {
            _dosageUnit = State(initialValue: medication.dosageUnit)
            _customUnit = State(initialValue: "")
            _isCustomUnitSelected = State(initialValue: false)
        } else {
            _dosageUnit = State(initialValue: "Custom")
            _customUnit = State(initialValue: medication.dosageUnit)
            _isCustomUnitSelected = State(initialValue: true)
        }
        
        _iconName = State(initialValue: medication.iconName)
        _frequency = State(initialValue: medication.frequency)
        _timeToTake = State(initialValue: medication.timeToTake)
        _reminderTimes = State(initialValue: medication.reminderTimes)
        _notes = State(initialValue: medication.notes ?? "")
        _enableNotification = State(initialValue: medication.notificationIDs.count > 0 || medication.notificationID != nil)
        
        // Set up pill count tracking
        if let pillCount = medication.pillCount {
            _pillCountString = State(initialValue: "\(pillCount)")
        } else {
            _pillCountString = State(initialValue: "")
        }
        
        _pillsPerDoseString = State(initialValue: "\(medication.pillsPerDose)")
        
        if let refillThreshold = medication.refillThreshold {
            _refillThresholdString = State(initialValue: "\(refillThreshold)")
        } else {
            _refillThresholdString = State(initialValue: "")
        }
        
        _trackPillCount = State(initialValue: medication.pillCount != nil)
        _isOneTimeWithFollowUp = State(initialValue: medication.isOneTimeWithFollowUp)
        _medicationType = State(initialValue: medication.medicationType)
        _isADHDMedication = State(initialValue: medication.medicationType != .other)
        _isExtendedRelease = State(initialValue: medication.isExtendedRelease)
        _enableDailyCheckIn = State(initialValue: medication.enableDailyCheckIn)
        _enableStimulantPhaseNotifications = State(initialValue: medication.enableStimulantPhaseNotifications)
        let defaultCheckInTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
        _useCustomDailyCheckInTime = State(initialValue: medication.dailyCheckInTime != nil)
        _customDailyCheckInTime = State(initialValue: medication.dailyCheckInTime ?? defaultCheckInTime)
        if let onset = medication.onsetMinutes {
            _onsetMinutesString = State(initialValue: "\(onset)")
        } else {
            _onsetMinutesString = State(initialValue: "")
        }
        if let duration = medication.durationMinutes {
            _durationMinutesString = State(initialValue: "\(duration)")
        } else {
            _durationMinutesString = State(initialValue: "")
        }
        if let effectsGoneMinutes = medication.effectsGoneMinutes {
            _effectsGoneMinutesString = State(initialValue: "\(effectsGoneMinutes)")
        } else {
            _effectsGoneMinutesString = State(initialValue: "")
        }
    }

    var body: some View {
        ZStack {
            // Enhanced background with subtle gradient
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
                        // Enhanced Header with progress indicator
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Edit Medication")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                    .padding(.top, -4)
                                
                                Spacer()
                                
                                // Progress indicator
                                HStack(spacing: 4) {
                                    ForEach(0..<4) { index in
                                        Circle()
                                            .fill(progressColor(index))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                            
                            Text("Update your medication details")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.bottom, 12)
                        }
                        .padding(.top, 32)
                        
                        // Enhanced Basic Information Section
                        FormSection(
                            title: "MEDICATION INFO",
                            cornerRadius: 20,
                            verticalPadding: 14,
                            includeTopDivider: true
                        ) {
                            VStack(spacing: 16) {
                                enhancedInputField(
                                    title: "Medication Name", 
                                    placeholder: "e.g., Aspirin, Tylenol",
                                    text: $name, 
                                    field: .name,
                                    isRequired: true,
                                    errorMessage: nameError
                                )
                                .id(Field.name)
                                
                                // Dosage and Unit in a row
                                HStack(alignment: .top, spacing: 24) {
                                    enhancedInputField(
                                        title: "Dosage", 
                                        placeholder: dosageUnit == "ml" ? "10" : "50", 
                                        text: $dosage, 
                                        field: .dosage,
                                        isRequired: true,
                                        errorMessage: dosageError,
                                        keyboardType: .decimalPad
                                    )
                                    .id(Field.dosage)
                                    
                                    // Enhanced unit picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Unit")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                        
                                        Menu {
                                            ForEach(dosageUnits, id: \.self) { unit in
                                                Button {
                                                    dosageUnit = unit
                                                    isCustomUnitSelected = unit == "custom"
                                                    HapticManager.shared.lightImpact()
                                                } label: {
                                                    Text(unit)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(dosageUnit)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.black.opacity(0.2))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                        }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }

                                // Add custom unit text field if needed - now moved under the dosage row
                                if isCustomUnitSelected {
                                    enhancedInputField(
                                        title: "Custom Unit Type", 
                                        placeholder: "e.g. drops, sprays", 
                                        text: $customUnit, 
                                        field: nil,
                                        isRequired: true,
                                        errorMessage: customUnit.isEmpty && showValidationErrors ? "Custom unit type is required" : nil
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .animation(.easeInOut, value: isCustomUnitSelected)
                                }
                            }
                        }
                        
                        // Enhanced Schedule Section
                        FormSection(
                            title: "SCHEDULE",
                            cornerRadius: 20,
                            verticalPadding: 14,
                            includeTopDivider: true
                        ) {
                            VStack(spacing: 16) {
                                // Frequency picker with better visual design
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("How Often You’ll Take It")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    let frequencyHasError = showValidationErrors && frequencyError != nil
                                    Menu {
                                        ForEach(frequencies, id: \.self) { freq in
                                            Button(action: {
                                                HapticManager.shared.lightImpact()
                                                if isPremiumFrequency(freq) && !userSettings.isPremiumUser {
                                                    showingPremiumUpgrade = true
                                                    return
                                                }
                                                frequency = freq
                                                setupReminderTimesForFrequency(freq)
                                                if freq == "As needed" {
                                                    enableNotification = false
                                                }
                                            }) {
                                                Text(displayFrequencyName(freq))
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(displayFrequencyName(frequency))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.65)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(height: standardFieldHeight)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.black.opacity(0.2))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(
                                                            frequencyHasError ? Color.red : Color(hex: "#C7C7BD").opacity(0.3),
                                                            lineWidth: frequencyHasError ? 2 : 1
                                                        )
                                                )
                                        )
                                    }
                                    .onChange(of: frequency) { newValue in
                                        validateField(.frequency, value: newValue)
                                    }
                                    if frequencyHasError {
                                        Text(frequencyError ?? "")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                }
                                .id(Field.frequency)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.vertical, 4)
                                
                                // Time pickers with enhanced design
                                if needsMultipleReminders {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Reminder Times")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                            .padding(.bottom, 6)
                                       
                                        ForEach(0..<reminderTimes.count, id: \.self) { index in
                                            TimePickerRow(
                                                title: "Dose \(index + 1)",
                                                time: $reminderTimes[index],
                                                titleOpacity: 0.7
                                            )
                                            .padding(.top, index == 0 ? 0 : 16)
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
                        
                        focusAndTimingSection
                            .onChange(of: isADHDMedication) { newValue in
                                if newValue {
                                    if medicationType == .other {
                                        medicationType = .stimulant
                                    }
                                    _ = validateADHDFields()
                                } else {
                                    medicationType = .other
                                    isExtendedRelease = false
                                    onsetMinutesString = ""
                                    durationMinutesString = ""
                                    effectsGoneMinutesString = ""
                                    onsetMinutesError = nil
                                    durationMinutesError = nil
                                    effectsGoneMinutesError = nil
                enableStimulantPhaseNotifications = false
                if enableDailyCheckIn {
                    useCustomDailyCheckInTime = true
                }
                                }
                            }
                            .onChange(of: medicationType) { newType in
                                if newType != .stimulant {
                                    isExtendedRelease = false
                                    onsetMinutesString = ""
                                    durationMinutesString = ""
                                    effectsGoneMinutesString = ""
                                    onsetMinutesError = nil
                                    durationMinutesError = nil
                                    effectsGoneMinutesError = nil
                enableStimulantPhaseNotifications = false
                if enableDailyCheckIn {
                    useCustomDailyCheckInTime = true
                }
                                } else {
                                    _ = validateADHDFields()
                                }
                            }

                        FormSection(title: "INVENTORY") {
                            VStack(spacing: 16) {
                                // Enhanced toggle with description
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(isOn: $trackPillCount.animation(.easeInOut)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("Track Pill Count")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                if !userSettings.isPremiumUser {
                                                    Button(action: {
                                                        showingPremiumUpgrade = true
                                                    }) {
                                                        PremiumLockIcon()
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                            Text(userSettings.isPremiumUser ?
                                                 "Get refill reminders and track usage" :
                                                 "Inventory tracking requires premium subscription")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        }
                                    }
                                    .onChange(of: trackPillCount) { isEnabled in
                                        if !isEnabled {
                                            pillCountError = nil
                                            pillsPerDoseError = nil
                                            refillThresholdError = nil
                                        } else {
                                            _ = validateInventoryFields()
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                    .disabled(!userSettings.isPremiumUser)
                                    .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                                    
                                    if !userSettings.isPremiumUser && trackPillCount {
                                        Button(action: {
                                            showingPremiumUpgrade = true
                                        }) {
                                            Text("Upgrade to Premium")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hex: "#D4A017"))
                                                .padding(.top, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                
                                if trackPillCount {
                                    VStack(spacing: 16) {
                                        HStack(spacing: 12) {
                                            enhancedInputField(
                                                title: "Total Pills", 
                                                placeholder: "30", 
                                                text: $pillCountString, 
                                                field: .pillCount, 
                                                isRequired: trackPillCount && userSettings.isPremiumUser,
                                                errorMessage: pillCountError,
                                                keyboardType: .numberPad
                                            )
                                            .id(Field.pillCount)
                                            
                                            enhancedInputField(
                                                title: "Per Dose", 
                                                placeholder: "1", 
                                                text: $pillsPerDoseString, 
                                                field: .pillsPerDose, 
                                                isRequired: trackPillCount,
                                                errorMessage: pillsPerDoseError,
                                                keyboardType: .numberPad
                                            )
                                            .id(Field.pillsPerDose)
                                        }

                                        enhancedInputField(
                                            title: "Refill Reminder", 
                                            placeholder: "5", 
                                            text: $refillThresholdString, 
                                            field: .refillThreshold, 
                                            isRequired: trackPillCount && userSettings.isPremiumUser,
                                            errorMessage: refillThresholdError,
                                            keyboardType: .numberPad
                                        )
                                        .id(Field.refillThreshold)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        
                        // Enhanced Notifications Section
                        if frequency != "As needed" {
                            FormSection(title: "NOTIFICATIONS") {
                                VStack(spacing: 16) {
                                    if needsMultipleReminders || frequency == "Once daily" {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Toggle(isOn: $isOneTimeWithFollowUp.animation(.easeInOut)) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text("Remind me again")
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                                        if !userSettings.isPremiumUser {
                                                            Button(action: {
                                                                showingPremiumUpgrade = true
                                                            }) {
                                                                PremiumLockIcon()
                                                            }
                                                            .buttonStyle(PlainButtonStyle())
                                                        }
                                                    }
                                                    Text(userSettings.isPremiumUser ?
                                                         "Get another reminder after 30 minutes if not taken" :
                                                         "One-time reminders require premium subscription")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                                }
                                            }
                                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                            .disabled(!userSettings.isPremiumUser)
                                            .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Enhanced Notes Section
                        FormSection(title: "NOTES") {
                            VStack(alignment: .leading, spacing: 8) {
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
                                        .overlay(
                                            Group {
                                                if notes.isEmpty {
                                                    Text("e.g., Take with food, side effects to watch for...")
                                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                        .padding(.top, 20)
                                                        .padding(.leading, 16)
                                                        .allowsHitTesting(false)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                        )
                                }
                            }
                            .id(Field.notes)
                        }
                        
                        // Enhanced Update Button
                        VStack(spacing: 12) {
                            if showValidationErrors && !isFormValid {
                                Text("Please fill in all required fields")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            NavigationActionButton(
                                title: "Update Medication",
                                icon: "checkmark",
                                variant: .primary,
                                isDisabled: !isFormValid
                            ) {
                                HapticManager.shared.mediumImpact()
                                updateMedication()
                            }
                            .accessibilityLabel("Update medication")
                        }
                        .padding(.vertical, 10)
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: focusedField) { _, field in
                    if let field = field {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
                .onChange(of: scrollTargetField) { field in
                    if let field = field {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .onAppear {
                setupKeyboardObservers()
                if !userSettings.isPremiumUser && isPremiumFrequency(frequency) {
                    frequency = "Once daily"
                    reminderTimes = []
                }
            }
            .onChange(of: userSettings.isPremiumUser) { isPremium in
                if !isPremium {
                    enableDailyCheckIn = false
                    useCustomDailyCheckInTime = false
                    if isPremiumFrequency(frequency) {
                        frequency = "Once daily"
                    }
                    reminderTimes = []
                }
            }
        }
        .sheet(isPresented: $showingFocusTimingGuidanceSheet) {
            FocusTimingGuidanceSheet(
                medicationName: focusTimingGuidanceMedicationName,
                guidance: focusTimingGuidance,
                isLoading: isFocusTimingLoading,
                errorMessage: focusTimingError,
                onApply: {
                    if let guidance = focusTimingGuidance {
                        applyFocusTimingGuidance(guidance)
                    }
                },
                onClose: nil
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(StoreManager.shared)
        }
    }
    
    // MARK: - Helper Methods

    private func handleFocusTimingGuidanceTap() {
        HapticManager.shared.lightImpact()
        showingFocusTimingGuidanceSheet = true
        requestFocusTimingGuidance(for: name)
    }

    private func requestFocusTimingGuidance(for query: String) {
        let trimmedName = query.trimmingCharacters(in: .whitespacesAndNewlines)
        focusTimingGuidanceMedicationName = trimmedName
        focusTimingGuidance = nil
        focusTimingError = nil
        isFocusTimingLoading = false

        guard !trimmedName.isEmpty else {
            return
        }

        guard userSettings.hasAIAccess() else {
            focusTimingError = "Upgrade to Pillr Premium to unlock AI-powered timing guidance or enter the timing manually."
            return
        }
        isFocusTimingLoading = true
        Task {
            do {
                let guidance = try await OpenAIService.shared.getFocusTimingGuidance(for: trimmedName)
                await MainActor.run {
                    focusTimingGuidance = guidance
                    focusTimingError = nil
                }
            } catch {
                await MainActor.run {
                    focusTimingError = error.localizedDescription
                }
            }
            await MainActor.run {
                isFocusTimingLoading = false
            }
        }
    }

    private func applyFocusTimingGuidance(_ guidance: FocusTimingGuidance) {
        isADHDMedication = guidance.medicationType != .other
        medicationType = guidance.medicationType
        isExtendedRelease = guidance.isExtendedRelease
        onsetMinutesError = nil
        durationMinutesError = nil
        effectsGoneMinutesError = nil

        if guidance.hasStimulantTiming,
           let onsetMinutes = guidance.typicalOnsetMinutes,
           let durationMinutes = guidance.typicalDurationMinutes {
            enableStimulantPhaseNotifications = true
            onsetMinutesString = "\(onsetMinutes)"
            durationMinutesString = "\(durationMinutes)"
            effectsGoneMinutesString = guidance.typicalEffectsGoneMaxMinutes.map { "\($0)" } ?? ""
            if userSettings.isPremiumUser {
                enableDailyCheckIn = true
                useCustomDailyCheckInTime = false
            }
        } else {
            enableStimulantPhaseNotifications = false
            onsetMinutesString = ""
            durationMinutesString = ""
            effectsGoneMinutesString = ""
            enableDailyCheckIn = false
            useCustomDailyCheckInTime = false
        }
    }

    private func setupReminderTimesForFrequency(_ freq: String) {
        if isPremiumFrequency(freq) && !userSettings.isPremiumUser {
            showingPremiumUpgrade = true
            frequency = "Once daily"
            reminderTimes = []
            return
        }
        switch freq {
        case "Twice daily":
            if reminderTimes.count != 2 {
                reminderTimes = [
                    Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                    Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                ]
            }
            enableNotification = true
        case "Three times daily":
            if reminderTimes.count != 3 {
                reminderTimes = [
                    Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                    Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
                    Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                ]
            }
            enableNotification = true
        case "As needed":
            reminderTimes = []
            enableNotification = false
        default:
            reminderTimes = []
            enableNotification = true
        }
    }

    private func isPremiumFrequency(_ frequency: String) -> Bool {
        frequency == "Twice daily" || frequency == "Three times daily"
    }

    private func displayFrequencyName(_ frequency: String) -> String {
        if isPremiumFrequency(frequency) && !userSettings.isPremiumUser {
            return "\(frequency) · Premium"
        }
        return frequency
    }
    
    // MARK: - Helper Views
    
    private func FormSection<Content: View>(
        title: String,
        cornerRadius: CGFloat = 20,
        verticalPadding: CGFloat = 14,
        includeTopDivider: Bool = true,
        backgroundColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let resolvedBackground = backgroundColor ?? formSectionBackgroundColor
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                if includeTopDivider {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.bottom, 10)
                }
                content()
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(resolvedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var focusAndTimingSection: some View {
        VStack(spacing: 16) {
            FormSection(title: "FOCUS & TIMING") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Is This an ADHD Medication?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))

                        Picker("ADHD medication", selection: $isADHDMedication) {
                            Text("Yes").tag(true)
                            Text("No").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    if isADHDMedication {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What kind of ADHD medication?")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#E8E8E0"))

                            Picker("Medication type", selection: $medicationType) {
                                Text("Stimulant").tag(MedicationType.stimulant)
                                Text("Non-stimulant").tag(MedicationType.nonStimulant)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    if isADHDMedication && medicationType == .stimulant {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $enableStimulantPhaseNotifications) {
                                    Text("Turn on focus window")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                              .onChange(of: enableStimulantPhaseNotifications) { enabled in
                                  if !enabled {
                                      onsetMinutesString = ""
                                      durationMinutesString = ""
                                      effectsGoneMinutesString = ""
                                      onsetMinutesError = nil
                                      durationMinutesError = nil
                                      effectsGoneMinutesError = nil
                                      enableDailyCheckIn = false
                                      useCustomDailyCheckInTime = false
                                  }
                              }

                                Text("Use these times to map your focus sessions. Pillr uses the start and fade windows to help you plan when you’ll be at your sharpest and when to ease into breaks.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .padding(.leading, 6)
                                    .padding(.top, 4)
                            }

                            HStack(spacing: 6) {
                                Text("Need help matching typical timing?")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                Spacer()
                                Button(action: handleFocusTimingGuidanceTap) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(Color(hex: "#C7C7BD").opacity(0.25))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Lookup typical focus timing for this medication")
                            }
                            .padding(.horizontal, 6)

                            if enableStimulantPhaseNotifications {
                                VStack(alignment: .leading, spacing: 12) {
                                    minuteWheelPickerField(
                                        title: "Starts working after",
                                        selection: $onsetMinutesString,
                                        range: focusOnsetRange,
                                        field: .onsetMinutes,
                                        isRequired: true,
                                        errorMessage: onsetMinutesError
                                    )
                                    .id(Field.onsetMinutes)

                                    minuteWheelPickerField(
                                        title: "Lasts about",
                                        selection: $durationMinutesString,
                                        range: focusDurationRange,
                                        field: .durationMinutes,
                                        isRequired: true,
                                        errorMessage: durationMinutesError
                                    )
                                    .id(Field.durationMinutes)

                                    minuteWheelPickerField(
                                        title: "Most effects gone after",
                                        selection: $effectsGoneMinutesString,
                                        range: focusEffectsGoneRange,
                                        field: .effectsGoneMinutes,
                                        isRequired: true,
                                        errorMessage: effectsGoneMinutesError
                                    )
                                    .id(Field.effectsGoneMinutes)
                                }
                            }
                        }
                    }
                }
            }

            if medicationType == .stimulant && enableStimulantPhaseNotifications {
                FormSection(title: "DAILY CHECK-IN") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $enableDailyCheckIn) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Daily check-in")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    if !userSettings.isPremiumUser {
                                        Button(action: {
                                            showingPremiumUpgrade = true
                                        }) {
                                            PremiumLockIcon()
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                Text(userSettings.isPremiumUser ?
                                     "At the start of the fading window, Pillr will remind you to log focus and side effects for this medication." :
                                        "Daily check-ins require a premium subscription.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                        .disabled(!userSettings.isPremiumUser)
                        .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                        .onChange(of: enableDailyCheckIn) { newValue in
                            guard userSettings.isPremiumUser else {
                                enableDailyCheckIn = false
                                useCustomDailyCheckInTime = false
                                return
                            }
                            if !newValue {
                                useCustomDailyCheckInTime = false
                            }
                        }

                        if enableDailyCheckIn && userSettings.isPremiumUser {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Default reminder arrives around when the medication starts to wear off. Prefer a different time? Pick one below.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))

                                Toggle(isOn: $useCustomDailyCheckInTime) {
                                    Text("Choose a custom check-in time")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))

                                if useCustomDailyCheckInTime {
                                    TimePickerRow(title: "Check-in time", time: $customDailyCheckInTime)
                                    Text("Tip: the custom reminder only schedules after you log a dose, so pick a time you expect to reach after logging; logging after that time means today’s reminder waits until tomorrow.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            } else if medicationType != .stimulant {
                FormSection(title: "DAILY CHECK-IN") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $enableDailyCheckIn) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Daily wellness check-in")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    if !userSettings.isPremiumUser {
                                        Button(action: {
                                            showingPremiumUpgrade = true
                                        }) {
                                            PremiumLockIcon()
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                Text(userSettings.isPremiumUser ?
                                     "Get a daily reminder to reflect on how this medication felt." :
                                        "Daily check-ins require a premium subscription.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                        .disabled(!userSettings.isPremiumUser)
                        .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                        .onChange(of: enableDailyCheckIn) { isEnabled in
                            guard userSettings.isPremiumUser else {
                                enableDailyCheckIn = false
                                useCustomDailyCheckInTime = false
                                return
                            }
                            if isEnabled {
                                useCustomDailyCheckInTime = true
                            }
                        }

                        if enableDailyCheckIn && userSettings.isPremiumUser {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose a time for your check-in.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                                TimePickerRow(title: "Check-in time", time: $customDailyCheckInTime)
                                Text("If the medication isn't taken before the check-in time, the daily wellness check-in will not trigger.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func TimePickerRow(
        title: String,
        time: Binding<Date>,
        titleOpacity: Double = 1.0
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0").opacity(titleOpacity))
            
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(Color(hex: "#C7C7BD"))
                .frame(height: timePickerHeight)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func enhancedInputField(
        title: String, 
        placeholder: String, 
        text: Binding<String>, 
        field: Field?,
        isRequired: Bool = false,
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            let showError = showValidationErrors && errorMessage != nil
            let numericFields: [Field] = [.dosage, .pillCount, .pillsPerDose, .refillThreshold, .onsetMinutes, .durationMinutes, .effectsGoneMinutes]

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    focusedField == field
                                    ? Color(hex: "#C7C7BD")
                                    : (showError
                                       ? Color.red
                                       : Color(hex: "#C7C7BD").opacity(0.3)),
                                    lineWidth: focusedField == field || showError ? 2 : 1
                                )
                        )
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    var processedValue = newValue

                    if let field = field, numericFields.contains(field) {
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            processedValue = filtered
                            text.wrappedValue = filtered
                        }
                    }

                    if let field = field {
                        validateField(field, value: processedValue)
                    }
                }
            
            if let errorMessage = errorMessage, showValidationErrors {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }

    private func minuteOptions(range: ClosedRange<Int>, currentValue: String) -> [Int] {
        var options: [Int] = []
        let specialOptions = [30, 45]

        for value in specialOptions where range.contains(value) {
            options.append(value)
        }

        if range.upperBound >= 60 {
            let startHour = max(60, ((range.lowerBound + 59) / 60) * 60)
            for value in stride(from: startHour, through: range.upperBound, by: 60) {
                if !options.contains(value) {
                    options.append(value)
                }
            }
        }

        if let current = Int(currentValue), current > 0, !options.contains(current) {
            options.append(current)
        }

        options.sort()
        return options
    }

    private func hoursLabel(for minutes: Int) -> String {
        if minutes == 30 || minutes == 45 {
            return "\(minutes) min"
        }
        let hours = Double(minutes) / 60.0
        let isWhole = hours.truncatingRemainder(dividingBy: 1) == 0
        let formatted = isWhole ? String(format: "%.0f", hours) : String(format: "%.2f", hours)
        let trimmed = formatted
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        return "\(trimmed) hr"
    }

    @ViewBuilder
    private func minuteWheelPickerField(
        title: String,
        selection: Binding<String>,
        range: ClosedRange<Int>,
        field: Field?,
        isRequired: Bool = false,
        errorMessage: String? = nil
    ) -> some View {
        let showError = showValidationErrors && errorMessage != nil
        let options = minuteOptions(range: range, currentValue: selection.wrappedValue)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .bold))
                }
            }

            Picker(title, selection: selection) {
                Text("Select").tag("")
                ForEach(options, id: \.self) { minutes in
                    Text(hoursLabel(for: minutes)).tag("\(minutes)")
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .accentColor(Color(hex: "#C7C7BD"))
            .frame(height: timePickerHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                showError ? Color.red : Color(hex: "#C7C7BD").opacity(0.3),
                                lineWidth: showError ? 2 : 1
                            )
                    )
            )
            .onChange(of: selection.wrappedValue) { _, newValue in
                if let field = field {
                    validateField(field, value: newValue)
                }
            }

            if let errorMessage = errorMessage, showValidationErrors {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private func FrequencyCard(frequency: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(frequency)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? Color(hex: "#404C42") : Color(hex: "#C7C7BD"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color(hex: "#C7C7BD") : Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.3), 
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // Helper function to format the time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Validation to ensure required fields are not empty
    private var isFormValid: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let dosageValid = !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let frequencyValid = !frequency.isEmpty
        
        // Validate custom unit if selected
        let customUnitValid = dosageUnit != "custom" || (dosageUnit == "custom" && !customUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if needsMultipleReminders && reminderTimes.isEmpty {
            return false
        }

        let inventoryRequired = trackPillCount && userSettings.isPremiumUser
        let inventoryValid = !inventoryRequired || inventoryFieldsValid
        let adhdRequired = isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications
        let adhdValid = !adhdRequired || adhdFieldsValid

        return nameValid &&
            dosageValid &&
            frequencyValid &&
            nameError == nil &&
            dosageError == nil &&
            customUnitValid &&
            inventoryValid &&
            adhdValid
    }

    private func firstInvalidField() -> Field? {
        if nameError != nil {
            return .name
        }
        if dosageError != nil {
            return .dosage
        }
        if frequencyError != nil {
            return .frequency
        }
        if trackPillCount && userSettings.isPremiumUser {
            if pillCountError != nil {
                return .pillCount
            }
            if pillsPerDoseError != nil {
                return .pillsPerDose
            }
            if refillThresholdError != nil {
                return .refillThreshold
            }
        }
        if isADHDMedication && medicationType == .stimulant {
            if onsetMinutesError != nil {
                return .onsetMinutes
            }
            if durationMinutesError != nil {
                return .durationMinutes
            }
            if effectsGoneMinutesError != nil {
                return .effectsGoneMinutes
            }
        }
        return nil
    }
    
    // Field navigation helpers
    private var canMoveToPreviousField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name: return false
        case .dosage, .frequency, .notes, .pillCount, .pillsPerDose, .refillThreshold, .durationMinutes, .effectsGoneMinutes: return true
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
        case .durationMinutes: return true
        case .effectsGoneMinutes: return false
        }
    }

    private func moveToPreviousField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: break
        case .dosage: focusedField = .name
        case .frequency: focusedField = .dosage
        case .notes: focusedField = trackPillCount ? .refillThreshold : .frequency
        case .pillCount: focusedField = .notes
        case .pillsPerDose: focusedField = .pillCount
        case .refillThreshold: focusedField = .pillsPerDose
        case .durationMinutes: focusedField = .onsetMinutes
        case .effectsGoneMinutes: focusedField = .durationMinutes
        case .onsetMinutes: focusedField = nil
        }
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: focusedField = .dosage
        case .dosage: focusedField = .frequency
        case .frequency: focusedField = trackPillCount ? .pillCount : .notes
        case .notes:
            focusedField = trackPillCount ? .pillCount : nil
        case .pillCount: focusedField = .pillsPerDose
        case .pillsPerDose: focusedField = .refillThreshold
        case .refillThreshold: focusedField = .notes
        case .onsetMinutes: focusedField = .durationMinutes
        case .durationMinutes: focusedField = .effectsGoneMinutes
        case .effectsGoneMinutes: focusedField = nil
        }
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
    
    // Update the medication in the store
    private func updateMedication() {
        // Validate form
        showValidationErrors = false
        validateForm()
        if !isFormValid {
            showValidationErrors = true
            scrollTargetField = firstInvalidField()
            return
        }

        scrollTargetField = nil
        
        // Use custom unit if "Custom" is selected
        let finalDosageUnit = dosageUnit == "custom" && !customUnit.isEmpty ? customUnit : dosageUnit
        
        // Create an updated medication object with the new values
        var updatedMedication = medication
        updatedMedication.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.dosageUnit = finalDosageUnit
        updatedMedication.iconName = iconName
        updatedMedication.frequency = frequency
        updatedMedication.medicationType = medicationType
        let hasFocusWindow = medicationType == .stimulant && enableStimulantPhaseNotifications
        let supportsGeneralCheckIn = medicationType != .stimulant
        let onsetMinutes = hasFocusWindow ? Int(onsetMinutesString) : nil
        let durationMinutes = hasFocusWindow ? Int(durationMinutesString) : nil
        let effectsGoneMinutes = hasFocusWindow ? Int(effectsGoneMinutesString) : nil
        let shouldEnableDailyCheckIn = userSettings.isPremiumUser && enableDailyCheckIn && (hasFocusWindow || supportsGeneralCheckIn)
        let shouldUseCustomDailyCheckInTime = supportsGeneralCheckIn || useCustomDailyCheckInTime
        let selectedDailyCheckInTime = (shouldEnableDailyCheckIn && shouldUseCustomDailyCheckInTime) ? customDailyCheckInTime : nil
        if medicationType == .stimulant {
            updatedMedication.isExtendedRelease = isExtendedRelease
            if hasFocusWindow {
                updatedMedication.onsetMinutes = onsetMinutes
                updatedMedication.durationMinutes = durationMinutes
                updatedMedication.effectsGoneMinutes = effectsGoneMinutes
                updatedMedication.enableDailyCheckIn = shouldEnableDailyCheckIn
                updatedMedication.dailyCheckInTime = shouldEnableDailyCheckIn ? selectedDailyCheckInTime : nil
            } else {
                updatedMedication.onsetMinutes = nil
                updatedMedication.durationMinutes = nil
                updatedMedication.effectsGoneMinutes = nil
                updatedMedication.enableDailyCheckIn = false
                updatedMedication.dailyCheckInTime = nil
            }
            updatedMedication.enableStimulantPhaseNotifications = enableStimulantPhaseNotifications
        } else {
            updatedMedication.isExtendedRelease = false
            updatedMedication.onsetMinutes = nil
            updatedMedication.durationMinutes = nil
            updatedMedication.effectsGoneMinutes = nil
            updatedMedication.enableDailyCheckIn = shouldEnableDailyCheckIn
            updatedMedication.dailyCheckInTime = shouldEnableDailyCheckIn ? selectedDailyCheckInTime : nil
            updatedMedication.enableStimulantPhaseNotifications = false
        }
        updatedMedication.timeToTake = timeToTake
        updatedMedication.reminderTimes = needsMultipleReminders ? reminderTimes : []
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        updatedMedication.isOneTimeWithFollowUp = isOneTimeWithFollowUp
        
        // Handle pill tracking
        if trackPillCount {
            updatedMedication.pillCount = Int(pillCountString) ?? 0
            updatedMedication.pillsPerDose = Int(pillsPerDoseString) ?? 1
            updatedMedication.refillThreshold = refillThresholdString.isEmpty ? nil : Int(refillThresholdString)
        } else {
            updatedMedication.pillCount = nil
            updatedMedication.pillsPerDose = 1
            updatedMedication.refillThreshold = nil
        }
        
        // Update the medication in the store - should only be enabled if not "As needed"
        store.updateMedication(updatedMedication, enableNotification: enableNotification && frequency != "As needed")
        
        onUpdate()
        dismiss()
    }
    
    private func validateForm() {
        validateField(.name, value: name)
        validateField(.dosage, value: dosage)
        validateField(.frequency, value: frequency)
        _ = validateInventoryFields()
        _ = validateADHDFields()
    }

    private var inventoryFieldsValid: Bool {
        let trimmedPillCount = pillCountString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPillsPerDose = pillsPerDoseString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRefillThreshold = refillThresholdString.trimmingCharacters(in: .whitespacesAndNewlines)
        let pillCountValue = Int(trimmedPillCount) ?? 0
        let pillsPerDoseValue = Int(trimmedPillsPerDose) ?? 0
        let refillThresholdValue = Int(trimmedRefillThreshold) ?? 0
        let pillCountValid = !trimmedPillCount.isEmpty && pillCountValue > 0
        let pillsPerDoseValid = !trimmedPillsPerDose.isEmpty && pillsPerDoseValue > 0
        let refillThresholdValid = !trimmedRefillThreshold.isEmpty && refillThresholdValue > 0
        return pillCountValid && pillsPerDoseValid && refillThresholdValid
    }

    private var adhdFieldsValid: Bool {
        guard isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications else {
            return true
        }

        let trimmedOnset = onsetMinutesString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDuration = durationMinutesString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEffectsGone = effectsGoneMinutesString.trimmingCharacters(in: .whitespacesAndNewlines)
        let onsetValid = !trimmedOnset.isEmpty && (Int(trimmedOnset) ?? 0) > 0
        let durationValid = !trimmedDuration.isEmpty && (Int(trimmedDuration) ?? 0) > 0
        let effectsGoneValid = !trimmedEffectsGone.isEmpty && (Int(trimmedEffectsGone) ?? 0) > 0
        return onsetValid && durationValid && effectsGoneValid
    }

    private func validateField(_ field: Field?, value: String) {
        guard let field = field else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        switch field {
        case .name:
            nameError = trimmed.isEmpty ? "Medication name is required" : nil
        case .dosage:
            dosageError = trimmed.isEmpty ? "Dosage is required" : nil
        case .frequency:
            frequencyError = trimmed.isEmpty ? "Frequency is required" : nil
        case .pillCount:
            if trackPillCount && userSettings.isPremiumUser {
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
        case .pillsPerDose:
            if !trackPillCount {
                pillsPerDoseError = nil
                break
            }
            if trimmed.isEmpty {
                pillsPerDoseError = "Pills per dose is required"
            } else if let count = Int(trimmed), count > 0 {
                pillsPerDoseError = nil
            } else {
                pillsPerDoseError = "Enter a valid number"
            }
        case .refillThreshold:
            if trackPillCount && userSettings.isPremiumUser {
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
            if !(isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications) {
                onsetMinutesError = nil
                break
            }
            if trimmed.isEmpty {
                onsetMinutesError = "Onset time is required"
            } else if let minutes = Int(trimmed), minutes > 0 {
                onsetMinutesError = nil
            } else {
                onsetMinutesError = "Enter a valid number"
            }
        case .durationMinutes:
            if !(isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications) {
                durationMinutesError = nil
                break
            }
            if trimmed.isEmpty {
                durationMinutesError = "Fade start time is required"
            } else if let minutes = Int(trimmed), minutes > 0 {
                durationMinutesError = nil
            } else {
                durationMinutesError = "Enter a valid number"
            }
        case .effectsGoneMinutes:
            if !(isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications) {
                effectsGoneMinutesError = nil
                break
            }
            if trimmed.isEmpty {
                effectsGoneMinutesError = "Effects gone time is required"
            } else if let minutes = Int(trimmed), minutes > 0 {
                effectsGoneMinutesError = nil
            } else {
                effectsGoneMinutesError = "Enter a valid number"
            }
        default:
            break
        }
    }

    private func validateInventoryFields() -> Bool {
        guard trackPillCount && userSettings.isPremiumUser else {
            pillCountError = nil
            pillsPerDoseError = nil
            refillThresholdError = nil
            return true
        }

        validateField(.pillCount, value: pillCountString)
        validateField(.pillsPerDose, value: pillsPerDoseString)
        validateField(.refillThreshold, value: refillThresholdString)

        return pillCountError == nil && pillsPerDoseError == nil && refillThresholdError == nil
    }

    private func validateADHDFields() -> Bool {
        guard isADHDMedication && medicationType == .stimulant && enableStimulantPhaseNotifications else {
            onsetMinutesError = nil
            durationMinutesError = nil
            effectsGoneMinutesError = nil
            return true
        }

        validateField(.onsetMinutes, value: onsetMinutesString)
        validateField(.durationMinutes, value: durationMinutesString)
        validateField(.effectsGoneMinutes, value: effectsGoneMinutesString)

        return onsetMinutesError == nil && durationMinutesError == nil && effectsGoneMinutesError == nil
    }
} 
