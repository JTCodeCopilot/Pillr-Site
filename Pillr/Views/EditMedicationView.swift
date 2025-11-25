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
    @State private var enableDailyCheckIn: Bool = false
    @State private var enableStimulantPhaseNotifications: Bool = false
    @State private var useCustomDailyCheckInTime: Bool = false
    @State private var customDailyCheckInTime: Date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingPremiumUpgrade: Bool = false
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
    @State private var frequencyError: String? = nil
    @State private var scrollTargetField: Field? = nil

    enum Field {
        case name, dosage, frequency, notes, pillCount, pillsPerDose, refillThreshold, onsetMinutes, durationMinutes
    }

    let frequencies = ["Once daily", "Twice daily", "Three times daily", "As needed"]
    let dosageUnits = ["mg", "ml", "tablets", "capsules", "custom"]
    private let standardFieldHeight: CGFloat = 52
    
    // Computed properties
    private var needsMultipleReminders: Bool {
        return frequency == "Twice daily" || frequency == "Three times daily"
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
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Enhanced Header with progress indicator
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Edit Medication")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
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
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Enhanced Basic Information Section
                        FormSection(title: "MEDICATION INFO") {
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
                                HStack(spacing: 12) {
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
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 12)
                                            .frame(minWidth: 90)
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
                                    .frame(minWidth: 110)
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
                        FormSection(title: "SCHEDULE") {
                            VStack(spacing: 16) {
                                // Frequency picker with better visual design
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("How often?")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                    let frequencyHasError = showValidationErrors && frequencyError != nil
                                    Menu {
                                        ForEach(frequencies, id: \.self) { freq in
                                            Button(action: {
                                                HapticManager.shared.lightImpact()
                                                frequency = freq
                                                setupReminderTimesForFrequency(freq)
                                                if freq == "As needed" {
                                                    enableNotification = false
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
                                
                                // Time pickers with enhanced design
                                if needsMultipleReminders {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Reminder Times")
                                            .font(.system(size: 16, weight: .semibold))
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
                        
                        // ADHD / Stimulant timing section
                        FormSection(title: "FOCUS & TIMING") {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Is this an ADHD medication?")
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
                                        Toggle(isOn: $isExtendedRelease) {
                                            Text("Extended-release formulation")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                        }
                                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))

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
                                                    onsetMinutesError = nil
                                                    durationMinutesError = nil
                                                    enableDailyCheckIn = false
                                                    useCustomDailyCheckInTime = false
                                                }
                                            }

                                            Text("Send alerts when the medication starts working and 10 minutes before it wears off.")
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
                                            .id(Field.onsetMinutes)

                                            enhancedInputField(
                                                title: "Lasts about (minutes)",
                                                placeholder: "240",
                                                text: $durationMinutesString,
                                                field: .durationMinutes,
                                                isRequired: true,
                                                errorMessage: durationMinutesError,
                                                keyboardType: .numberPad
                                            )
                                            .id(Field.durationMinutes)

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
                                                }
                                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                                .onChange(of: enableDailyCheckIn) { newValue in
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

                                                        if useCustomDailyCheckInTime {
                                                            TimePickerRow(title: "Check-in time", time: $customDailyCheckInTime)
                                                        }
                                                    }
                                                    .padding(.top, 4)
                                                }
                                            }
                                        }

                                        Text("These help Pillr estimate when this medication will start working and when it will wear off, so you can plan focus time and breaks.")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                    }
                                }
                            }
                        }
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
                                enableDailyCheckIn = false
                                useCustomDailyCheckInTime = false
                                onsetMinutesError = nil
                                durationMinutesError = nil
                                enableStimulantPhaseNotifications = false
                            }
                        }
                        .onChange(of: medicationType) { newType in
                            if newType != .stimulant {
                                isExtendedRelease = false
                                onsetMinutesString = ""
                                durationMinutesString = ""
                                enableDailyCheckIn = false
                                useCustomDailyCheckInTime = false
                                onsetMinutesError = nil
                                durationMinutesError = nil
                                enableStimulantPhaseNotifications = false
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
                                                        Text("One-time with Follow-up")
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                                        if !userSettings.isPremiumUser {
                                                            Button(action: {
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
                            Button {
                                HapticManager.shared.mediumImpact()
                                updateMedication()
                            } label: {
                                HStack {
                                    Text("Update Medication")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(isFormValid ? Color(hex: "#404C42") : Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: isFormValid ? [
                                            Color(hex: "#E8E8E0"),
                                            Color(hex: "#D0D0C8")
                                        ] : [
                                            Color.gray.opacity(0.6),
                                            Color.gray.opacity(0.4)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: isFormValid ? Color.black.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 4)
                            }
                            .disabled(!isFormValid)
                            .buttonStyle(ScaleButtonStyle())
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
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(StoreManager.shared)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupReminderTimesForFrequency(_ freq: String) {
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
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func FormSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private func TimePickerRow(title: String, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(Color(hex: "#C7C7BD"))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
        }
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
            let numericFields: [Field] = [.dosage, .pillCount, .pillsPerDose, .refillThreshold, .onsetMinutes, .durationMinutes]

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
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
        }
        return nil
    }
    
    // Field navigation helpers
    private var canMoveToPreviousField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name: return false
        case .dosage, .frequency, .notes, .pillCount, .pillsPerDose, .refillThreshold, .durationMinutes: return true
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
        case .notes: focusedField = trackPillCount ? .refillThreshold : .frequency
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
        case .frequency: focusedField = trackPillCount ? .pillCount : .notes
        case .notes:
            focusedField = trackPillCount ? .pillCount : nil
        case .pillCount: focusedField = .pillsPerDose
        case .pillsPerDose: focusedField = .refillThreshold
        case .refillThreshold: focusedField = .notes
        case .onsetMinutes: focusedField = .durationMinutes
        case .durationMinutes: focusedField = nil
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
        if medicationType == .stimulant {
            updatedMedication.isExtendedRelease = isExtendedRelease
            if enableStimulantPhaseNotifications {
                updatedMedication.onsetMinutes = Int(onsetMinutesString)
                updatedMedication.durationMinutes = Int(durationMinutesString)
                updatedMedication.enableDailyCheckIn = enableDailyCheckIn
                updatedMedication.dailyCheckInTime = (enableDailyCheckIn && useCustomDailyCheckInTime) ? customDailyCheckInTime : nil
            } else {
                updatedMedication.onsetMinutes = nil
                updatedMedication.durationMinutes = nil
                updatedMedication.enableDailyCheckIn = false
                updatedMedication.dailyCheckInTime = nil
            }
            updatedMedication.enableStimulantPhaseNotifications = enableStimulantPhaseNotifications
        } else {
            updatedMedication.isExtendedRelease = false
            updatedMedication.onsetMinutes = nil
            updatedMedication.durationMinutes = nil
            updatedMedication.enableDailyCheckIn = false
            updatedMedication.dailyCheckInTime = nil
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
        let onsetValid = !trimmedOnset.isEmpty && (Int(trimmedOnset) ?? 0) > 0
        let durationValid = !trimmedDuration.isEmpty && (Int(trimmedDuration) ?? 0) > 0
        return onsetValid && durationValid
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
            return true
        }

        validateField(.onsetMinutes, value: onsetMinutesString)
        validateField(.durationMinutes, value: durationMinutesString)

        return onsetMinutesError == nil && durationMinutesError == nil
    }
} 
