//
//  MedicationsListView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct MedicationsListView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @State private var showingLogSheetFor: Medication?
    @State private var selectedMedicationToEdit: Medication?
    @State private var showingAddSheet = false
    @State private var scrolledOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingArchivedSheet = false
    @State private var medicationToArchive: Medication? = nil
    @State private var showArchiveAlert = false
    @State private var showingInteractionSheet = false
    @State private var interactionCheckError: String? = nil
    @State private var foundInteractions: [DrugInteraction]? = nil
    @State private var isCheckingInteractions = false
    @State private var showingInteractionResultSheet = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MedicationsListMainContent(
                store: store,
                showingAddSheet: $showingAddSheet,
                scrolledOffset: $scrolledOffset,
                showingLogSheetFor: $showingLogSheetFor,
                selectedMedicationToEdit: $selectedMedicationToEdit,
                medicationToArchive: $medicationToArchive,
                showArchiveAlert: $showArchiveAlert,
                showingArchivedSheet: $showingArchivedSheet,
                showingInteractionSheet: $showingInteractionSheet,
                isCheckingInteractions: $isCheckingInteractions,
                onCheckAllInteractions: checkAllMedicationInteractions
            )
            AddMedicationFloatingButton(showingAddSheet: $showingAddSheet)
        }
        .sheet(item: $showingLogSheetFor) { med in
            LogMedicationView(medicationToLog: med)
                .environmentObject(store)
        }
        .sheet(item: $selectedMedicationToEdit) { med in
            NavigationView {
                EditMedicationView(medication: med, onUpdate: {})
                    .environmentObject(store)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddMedicationView(onAdd: { showingAddSheet = false })
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showingArchivedSheet) {
            ArchivedMedicationsSheet(
                store: store,
                showingArchivedSheet: $showingArchivedSheet
            )
        }
        .sheet(isPresented: $showingInteractionSheet) {
            InteractionSearchView()
        }
        .sheet(isPresented: $showingInteractionResultSheet) {
            InteractionResultsSheetView(
                isPresented: $showingInteractionResultSheet,
                interactions: foundInteractions ?? [],
                error: interactionCheckError
            )
        }
        .alert(isPresented: $showArchiveAlert) {
            Alert(
                title: Text("Archive Medication"),
                message: Text("Are you sure you want to archive \(medicationToArchive?.name ?? "this medication")? You can restore it later from the archive."),
                primaryButton: .destructive(Text("Archive")) {
                    if let med = medicationToArchive {
                        store.archiveMedication(med)
                    }
                    medicationToArchive = nil
                },
                secondaryButton: .cancel {
                    medicationToArchive = nil
                }
            )
        }
    }
    
    private func checkAllMedicationInteractions() async {
        guard !store.activeMedications.isEmpty else {
            self.interactionCheckError = "You don't have any active medications to check."
            self.showingInteractionResultSheet = true
            return
        }
        
        isCheckingInteractions = true
        self.interactionCheckError = nil
        self.foundInteractions = nil
        
        do {
            let interactions = try await OpenAIService.shared.checkInteractionsForAllMedications(medications: store.activeMedications)
            self.foundInteractions = interactions
        } catch {
            self.interactionCheckError = "Failed to check interactions: \(error.localizedDescription)"
        }
        
        isCheckingInteractions = false
        showingInteractionResultSheet = true
    }
}

// MARK: - Subviews

@ViewBuilder
fileprivate func EmptyMedicationsView(showingAddSheet: Binding<Bool>) -> some View {
    VStack(spacing: 20) {
        Image(systemName: "pills")
            .font(.system(size: 50))
            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            .padding(.bottom, 10)
        Text("Your medication list is empty")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(Color(hex: "#C7C7BD"))
        Text("Add your medications to get reminders and track when you take them")
            .font(.system(size: 14))
            .multilineTextAlignment(.center)
            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            .padding(.horizontal)
        Button {
            showingAddSheet.wrappedValue = true
        } label: {
            Text("Add Medication")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                )
        }
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Your medication list is empty. Add your first medication.")
}

@ViewBuilder
fileprivate func MedicationsListContent(
    store: MedicationStore,
    scrolledOffset: Binding<CGFloat>,
    horizontalInsets: CGFloat,
    showingLogSheetFor: Binding<Medication?>,
    selectedMedicationToEdit: Binding<Medication?>,
    medicationToArchive: Binding<Medication?>,
    showArchiveAlert: Binding<Bool>,
    showingArchivedSheet: Binding<Bool>,
    showingInteractionSheet: Binding<Bool>,
    isCheckingInteractions: Binding<Bool>,
    onCheckAllInteractions: @escaping () async -> Void
) -> some View {
    ScrollView {
        VStack(spacing: 24) {
            HStack {
                Text("Currently Taking")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Spacer()
                Button {
                    Task {
                        await onCheckAllInteractions()
                    }
                } label: {
                    if isCheckingInteractions.wrappedValue {
                        ProgressView()
                            .tint(Color(hex: "#C7C7BD"))
                    } else {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
                .disabled(isCheckingInteractions.wrappedValue)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.activeMedications.sorted(by: { $0.timeToTake < $1.timeToTake })) { med in
                    MedicationRow(
                        medication: med,
                        onLogTap: { 
                            HapticManager.shared.lightImpact()
                            showingLogSheetFor.wrappedValue = med 
                        },
                        onEditTap: { 
                            HapticManager.shared.lightImpact()
                            selectedMedicationToEdit.wrappedValue = med 
                        },
                        onArchiveTap: {
                            HapticManager.shared.warningNotification()
                            medicationToArchive.wrappedValue = med
                            showArchiveAlert.wrappedValue = true
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            if !store.archivedMedications.isEmpty {
                Button(action: { 
                    HapticManager.shared.lightImpact()
                    showingArchivedSheet.wrappedValue = true 
                }) {
                    HStack {
                        Image(systemName: "archivebox")
                        Text("View Archived Medications (")
                        Text("\(store.archivedMedications.count)")
                        Text(")")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 40)
        }
        .padding(.horizontal, horizontalInsets)
        .padding(.top, 10)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .global).minY
                )
            }
        )
    }
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
        scrolledOffset.wrappedValue = -value
    }
}

fileprivate struct AddMedicationFloatingButton: View {
    @Binding var showingAddSheet: Bool
    var body: some View {
        Button(action: {
            showingAddSheet = true
        }) {
            ZStack {
                // Updated 3D Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#DFDFD9"), // Lighter top highlight
                        Color(hex: "#C7C7BD"), // Main middle color
                        Color(hex: "#B8B8AE")  // Softer bottom shadow
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 64, height: 64) // Slightly smaller
                .clipShape(Circle())

                // Subtle inner highlight for depth
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 63, height: 63) // Slightly inset

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold)) // Slightly adjusted size and weight
                    .foregroundColor(Color(hex: "#3A443D")) // Darker, less saturated green
            }
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6) // Softer main shadow
            .shadow(color: Color(hex: "#2F352F").opacity(0.1), radius: 1, x: 0, y: 1) // Subtle secondary shadow
        }
        .hapticFeedback(.medium)
        .padding(.trailing, 20)
        .padding(.bottom, 50)
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Add new medication")
    }
}

@ViewBuilder
fileprivate func ArchivedMedicationsSheet(
    store: MedicationStore,
    showingArchivedSheet: Binding<Bool>
) -> some View {
    NavigationView {
        ZStack {
            Color(hex: "#404C42").ignoresSafeArea()
            List {
                ForEach(store.archivedMedications) { med in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(med.name)
                                .font(.headline)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            Text(med.dosage)
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        }
                        Spacer()
                        Button(action: { store.unarchiveMedication(med) }) {
                            Text("Unarchive")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#404C42"))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 16)
                                .background(Color(hex: "#C7C7BD"))
                                .cornerRadius(8)
                        }
                    }
                    .listRowBackground(Color(hex: "#404C42"))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Archived Medications")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { showingArchivedSheet.wrappedValue = false }
                    .foregroundColor(Color(hex: "#C7C7BD"))
            }
        }
    }
}

fileprivate struct MedicationsListMainContent: View {
    @ObservedObject var store: MedicationStore
    @Binding var showingAddSheet: Bool
    @Binding var scrolledOffset: CGFloat
    @Binding var showingLogSheetFor: Medication?
    @Binding var selectedMedicationToEdit: Medication?
    @Binding var medicationToArchive: Medication?
    @Binding var showArchiveAlert: Bool
    @Binding var showingArchivedSheet: Bool
    @Binding var showingInteractionSheet: Bool
    @Binding var isCheckingInteractions: Bool
    let onCheckAllInteractions: () async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private func horizontalInsets(for width: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular && width > 768 {
            return max((width - 650) / 2, 16)
        }
        return 16
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#404C42")
                .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
            VStack(spacing: 0) {
                if store.medications.isEmpty {
                    EmptyMedicationsView(showingAddSheet: $showingAddSheet)
                } else {
                    MedicationsListContent(
                        store: store,
                        scrolledOffset: $scrolledOffset,
                        horizontalInsets: horizontalInsets(for: UIScreen.main.bounds.width),
                        showingLogSheetFor: $showingLogSheetFor,
                        selectedMedicationToEdit: $selectedMedicationToEdit,
                        medicationToArchive: $medicationToArchive,
                        showArchiveAlert: $showArchiveAlert,
                        showingArchivedSheet: $showingArchivedSheet,
                        showingInteractionSheet: $showingInteractionSheet,
                        isCheckingInteractions: $isCheckingInteractions,
                        onCheckAllInteractions: onCheckAllInteractions
                    )
                }
            }
        }
    }
}

// MARK: - Preference Key for Scroll Position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

fileprivate func commonFormatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// New fileprivate struct for the header content of a MedicationRow
fileprivate struct MedicationRowHeaderView: View {
    let medication: Medication
    let cycleStatus: MedicationCycleStatus
    @Binding var showDetails: Bool
    let onLogTap: () -> Void

    // Moved statusDisplay computed property
    private var statusDisplay: (text: String, color: Color, show: Bool) {
        if medication.frequency == "As needed" {
            return ("", .clear, false) // No status text for "As needed" meds
        }
        switch cycleStatus {
        case .taken:
            return ("", .clear, false) // No status text when taken, button shows "Taken"
        case .skipped:
            return ("Skipped", Color(hex: "#C62828"), true)
        case .overdue(let minutesPast):
            return ("Overdue by \(formatTimeText(minutes: minutesPast))", Color(hex: "#FFA726"), true)
        case .due(let minutesRemaining):
            return ("Due in \(formatTimeText(minutes: minutesRemaining))", Color(hex: "#81C784"), true)
        case .asNeeded: // Add .asNeeded case
            return ("", .clear, false)
        }
    }
    
    // Format minutes into human-readable text
    private func formatTimeText(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if remainingMinutes == 0 {
                let hourText = hours == 1 ? "hour" : "hours"
                return "\(hours) \(hourText)"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }

    // Moved buttonProperties computed property
    private func buttonProperties() -> (iconName: String, text: String, fgColor: Color, bgColor: Color) {
        switch cycleStatus {
        case .taken:
            return (iconName: "checkmark.circle.fill", text: "Taken", fgColor: Color(hex: "#2E5339"), bgColor: Color(hex: "#C8E6C9"))
        case .skipped:
            return (iconName: "xmark.circle.fill", text: "Skipped", fgColor: Color(hex: "#C62828"), bgColor: Color(hex: "#FFCDD2"))
        case .overdue(_), .due(_):
            return (iconName: "circle", text: "Take Now", fgColor: Color(hex: "#E0E0E0"), bgColor: Color.black.opacity(0.4))
        case .asNeeded: // Add .asNeeded case
            return (iconName: "circle", text: "Take Now", fgColor: Color(hex: "#E0E0E0"), bgColor: Color.black.opacity(0.4))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            medicationInfoSection
            Spacer()
            statusAndButtonSection
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        }
    }
    
    // Medication information section (left side)
    private var medicationInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#E0E0E0"))
            
            Text(dosageString())
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#B0B0B0"))
            
            if let notes = medication.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#A0A0A0"))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 2)
            }
        }
    }
    
    private func dosageString() -> String {
        var baseString = "\(medication.dosage)"
        if medication.dosageUnit == "mg" || medication.dosageUnit == "ml" {
            baseString += " \(medication.dosageUnit)"
        }
        return "\(baseString) - \(medication.frequency)"
    }
    
    // Status and action button section (right side)
    private var statusAndButtonSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            statusSection
            actionButton
        }
    }
    
    // Status section with chevron
    private var statusSection: some View {
        let currentStatusDisplay = statusDisplay
        
        return Group {
            if currentStatusDisplay.show {
                HStack(spacing: 4) {
                    Text(currentStatusDisplay.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(currentStatusDisplay.color)
                    chevronIcon
                }
            } else {
                HStack {
                    Spacer()
                    chevronIcon
                        .padding(.vertical, 7)
                }
            }
        }
    }
    
    // Chevron icon
    private var chevronIcon: some View {
        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
    }
    
    // Action button
    private var actionButton: some View {
        let properties = buttonProperties()
        
        return Button(action: {
            handleButtonTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: properties.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(properties.fgColor)
                
                Text(properties.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(properties.fgColor)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(properties.bgColor)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Handle button tap with appropriate haptic feedback
    private func handleButtonTap() {
        switch cycleStatus {
        case .due(_), .overdue(_):
            HapticManager.shared.successNotification()
        case .taken, .skipped:
            HapticManager.shared.lightImpact()
        case .asNeeded: // Add .asNeeded case
            HapticManager.shared.lightImpact()
        }
        onLogTap()
    }
}

struct MedicationRow: View {
    let medication: Medication
    let onLogTap: () -> Void
    let onEditTap: () -> Void
    let onArchiveTap: (() -> Void)? // Optional for archived meds
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: MedicationStore
    @State private var isPressed = false
    @State private var showDetails = false
    
    // Check if the medication was taken today (and not skipped)
    private var wasTakenToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return store.logs.contains { log in
            log.medicationID == medication.id &&
            calendar.isDate(calendar.startOfDay(for: log.takenAt), inSameDayAs: today) &&
            !log.skipped // Ensure it was not a skipped log
        }
    }
    
    // Check if the medication was skipped today
    private var wasSkippedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return store.logs.contains { log in
            log.medicationID == medication.id &&
            calendar.isDate(calendar.startOfDay(for: log.takenAt), inSameDayAs: today) &&
            log.skipped // Ensure it was a skipped log
        }
    }
    
    // Helper to get the effective due time, considering the reset logic
    private var effectiveDueTime: Date {
        let now = Date()
        let calendar = Calendar.current
        
        var calculatedEffectiveTimeToTake = medication.timeToTake

        let medicationDayStart = calendar.startOfDay(for: medication.timeToTake)
        let currentDayStart = calendar.startOfDay(for: now)
        
        let dayDifferenceComponents = calendar.dateComponents([.day], from: medicationDayStart, to: currentDayStart)
        let dayDifference = dayDifferenceComponents.day ?? 0
        
        // If the original due date was two or more days ago, reset by calculating the next due time.
        if dayDifference >= 2 {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: medication.timeToTake)
            if var newPotentialDueTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                       minute: timeComponents.minute ?? 0,
                                                       second: 0,
                                                       of: now) {
                // If this time has already passed today, set it for the same time tomorrow
                if newPotentialDueTime < now {
                    newPotentialDueTime = calendar.date(byAdding: .day, value: 1, to: newPotentialDueTime) ?? newPotentialDueTime
                }
                calculatedEffectiveTimeToTake = newPotentialDueTime
            }
        }
        return calculatedEffectiveTimeToTake
    }

    // Calculates minutes to the effective due time
    private var minutesToEffectiveDueTime: Int {
        let now = Date()
        return Calendar.current.dateComponents([.minute], from: now, to: effectiveDueTime).minute ?? 0
    }
    
    private var cycleStatus: MedicationCycleStatus {
        if wasTakenToday { // Check if taken first
            return .taken
        } else if wasSkippedToday {
            return .skipped
        } else if medication.frequency == "As needed" { // Then check if it's "As needed" and not yet taken/skipped
            return .asNeeded
        } else {
            let minutes = minutesToEffectiveDueTime
            let calendar = Calendar.current
            let now = Date()

            if minutes < 0 { // It's past its effectiveDueTime
                // If effectiveDueTime was for a calendar day before today's start
                if effectiveDueTime < calendar.startOfDay(for: now) {
                    return .skipped
                } else { // Overdue today
                    return .overdue(minutesPast: abs(minutes))
                }
            } else { // Due in the future (today or later)
                return .due(minutesRemaining: minutes)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Use the new MedicationRowHeaderView
            MedicationRowHeaderView(
                medication: medication,
                cycleStatus: cycleStatus, // Pass the calculated cycleStatus
                showDetails: $showDetails,
                onLogTap: onLogTap
            )
            
            if showDetails {
                MedicationRowDetailsView(
                    medication: medication,
                    onEditTap: onEditTap,
                    onArchiveTap: onArchiveTap
                )
                .padding(.top, 8)
            }
        }
        .background(Color(hex: "#4A554D"))
        .cornerRadius(12)
        .overlay(borderOverlay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(commonFormatTime(medication.timeToTake))")
        .accessibilityHint(accessibilityHintText())
        .accessibilityAction(.default) {
            // Use pattern matching instead of the != operator
            switch cycleStatus {
            case .due(_), .overdue(_):
                onLogTap()
            case .taken, .skipped:
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
            case .asNeeded: // Add .asNeeded case
                onLogTap()
            }
        }
        .accessibilityAction(named: accessibilityActionName()) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        }
    }
    
    // Border overlay based on medication cycle status
    private var borderOverlay: some View {
        let borderColor: Color
        
        switch cycleStatus {
        case .taken:
            borderColor = Color(hex: "#81C784").opacity(0.5)
        case .skipped:
            borderColor = Color.red.opacity(0.5)
        case .due(_), .overdue(_):
            borderColor = Color(hex: "#606A63").opacity(0.5)
        case .asNeeded: // Add .asNeeded case
            borderColor = Color(hex: "#606A63").opacity(0.5) // Or a different color if desired
        }
        
        return RoundedRectangle(cornerRadius: 12)
            .stroke(borderColor, lineWidth: 1)
    }

    // Helper for accessibility hint text
    private func accessibilityHintText() -> String {
        switch cycleStatus {
        case .taken:
            return "Already taken today. Tap status or chevron to expand details."
        case .skipped:
            return "Skipped. Tap to log or tap status/chevron to expand details."
        case .due(_), .overdue(_):
            return "Tap 'Take Now' to log, or tap status/chevron to expand details."
        case .asNeeded: // Add .asNeeded case
            return "Tap 'Take Now' to log, or tap status/chevron to expand details."
        }
    }

    // Helper for accessibility action name
    private func accessibilityActionName() -> String {
        switch cycleStatus {
        case .taken, .skipped:
            return "View Details"
        case .due(_), .overdue(_):
            return "View Details Without Logging"
        case .asNeeded: // Add .asNeeded case
            return "View Details"
        }
    }
}

// MARK: - Medication Cycle Status Enum
fileprivate enum MedicationCycleStatus {
    case due(minutesRemaining: Int)
    case overdue(minutesPast: Int)
    case taken
    case skipped
    case asNeeded // New case
}

// MARK: - MedicationCycleStatus Equatable implementation
extension MedicationCycleStatus: Equatable {
    static func == (lhs: MedicationCycleStatus, rhs: MedicationCycleStatus) -> Bool {
        switch (lhs, rhs) {
        case (.taken, .taken), (.skipped, .skipped):
            return true
        case (.asNeeded, .asNeeded): // Add .asNeeded to Equatable
            return true
        case (.due(let lhsMinutes), .due(let rhsMinutes)):
            return lhsMinutes == rhsMinutes
        case (.overdue(let lhsMinutes), .overdue(let rhsMinutes)):
            return lhsMinutes == rhsMinutes
        default:
            return false
        }
    }
}

// MARK: - MedicationRowDetailsView
fileprivate struct MedicationRowDetailsView: View {
    let medication: Medication
    let onEditTap: () -> Void
    let onArchiveTap: (() -> Void)?

    private var reminderTimesString: String {
        if medication.reminderTimes.isEmpty {
            return commonFormatTime(medication.timeToTake) // Fallback to single timeToTake
        }
        return medication.reminderTimes.map { commonFormatTime($0) }.joined(separator: ", ")
    }

    private var notificationsEnabled: Bool {
        return !(medication.notificationID == nil && medication.notificationIDs.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Medication Name and Dosage (already in header, but good for context if needed here)
            // Text("\\(medication.name) - \\(medication.dosage)")
            //     .font(.system(size: 16, weight: .semibold))
            //     .foregroundColor(Color(hex: "#E0E0E0"))

            detailRow(icon: "clock.arrow.circlepath", label: "Frequency", value: medication.frequency)
            detailRow(icon: "alarm", label: "Reminders", value: reminderTimesString)
            detailRow(icon: notificationsEnabled ? "bell.fill" : "bell.slash.fill", label: "Notifications", value: notificationsEnabled ? "On" : "Off", valueColor: notificationsEnabled ? Color(hex: "#81C784") : .red)
            
            if let notes = medication.notes, !notes.isEmpty {
                detailRow(icon: "note.text", label: "Notes", value: notes, lineLimit: nil)
            }

            // Action buttons
            HStack(alignment: .center, spacing: 20) {
                Button(action: onEditTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                        Text("Edit")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .background(Color.black.opacity(0.2))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .cornerRadius(8)
                }

                if let archiveTap = onArchiveTap {
                    Button(action: archiveTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 13))
                            Text("Archive")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .cornerRadius(8)
                    }
                }
                Spacer() // Pushes buttons to the left if there's space
            }
            .padding(.top, 4) // Add a little space above buttons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16) // Ensure bottom padding
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String, valueColor: Color = Color(hex: "#C7C7BD").opacity(0.9), lineLimit: Int? = 1) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#A0A0A0"))
                .frame(width: 20, alignment: .center)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#A0A0A0"))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(lineLimit)
        }
    }
}

// Extension to convert ShapeStyle types to AnyShapeStyle
extension ShapeStyle {
    func anyShapeStyle() -> AnyShapeStyle {
        return AnyShapeStyle(self)
    }
}
