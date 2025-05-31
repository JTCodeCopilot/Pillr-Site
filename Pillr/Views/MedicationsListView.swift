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
    @State private var showingMedicationSelectionSheet = false
    @State private var interactionCheckError: String? = nil
    @State private var foundInteractions: [DrugInteraction]? = nil
    @State private var isCheckingInteractions = false
    @State private var showingInteractionResultSheet = false
    @State private var showingPremiumUpgrade = false
    
    var body: some View {
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
            onCheckAllInteractions: showMedicationSelectionSheet,
            onAddMedication: handleAddMedication
        )
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
                    .environmentObject(userSettings)
            }
        }
        .sheet(isPresented: $showingArchivedSheet) {
            ArchivedMedicationsSheet(
                store: store,
                showingArchivedSheet: $showingArchivedSheet
            )
        }

        .sheet(isPresented: $showingMedicationSelectionSheet) {
            MedicationInteractionSelectionSheet()
                .environmentObject(store)
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
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }
    
    private func showMedicationSelectionSheet() async {
        showingMedicationSelectionSheet = true
    }
    
    private func handleAddMedication() {
        let currentActiveMedications = store.activeMedications.count
        if userSettings.canAddMedication(currentCount: currentActiveMedications) {
            showingAddSheet = true
        } else {
            showingPremiumUpgrade = true
        }
    }
    
    private func checkAllMedicationInteractions() async {
        guard !store.activeMedications.isEmpty else {
            self.interactionCheckError = "You don't have any active medications to check."
            self.showingInteractionResultSheet = true
            return
        }
        
        guard store.activeMedications.count >= 2 else {
            self.interactionCheckError = "You need at least 2 active medications to check for interactions."
            self.showingInteractionResultSheet = true
            return
        }
        
        isCheckingInteractions = true
        self.interactionCheckError = nil
        self.foundInteractions = nil
        
        // AI interaction checking functionality removed
        self.interactionCheckError = "Interaction checking feature has been removed"
        
        isCheckingInteractions = false
        showingInteractionResultSheet = true
    }
}

// MARK: - Subviews

@ViewBuilder
fileprivate func EmptyMedicationsView(onAddMedication: @escaping () -> Void) -> some View {
    EmptyStateView(
        title: "Your medication list is empty",
        message: "",
        actionTitle: "Add Your First Medication",
        action: {
            HapticManager.shared.mediumImpact()
            onAddMedication()
        },
        icon: "pills.fill"
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Your medication list is empty. Add your first medication to get started.")
    .accessibilityHint("Double tap to add your first medication")
}

// Helper function to sort medications by priority (overdue first, then by due time)
fileprivate func sortedMedications(_ medications: [Medication]) -> [Medication] {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    
    return medications.sorted { med1, med2 in
        // Helper function to get medication status
        func getMedicationStatus(_ medication: Medication) -> (isOverdue: Bool, isAsNeeded: Bool, effectiveDueTime: Date) {
            // Check if taken or skipped today (simplified version of the logic from MedicationRow)
            // We'll use a simplified approach for sorting that doesn't check logs
            
            if medication.frequency == "As needed" {
                return (false, true, medication.timeToTake)
            }
            
            // Calculate effective due time (simplified version)
            var effectiveDueTime = medication.timeToTake
            let medicationDayStart = calendar.startOfDay(for: medication.timeToTake)
            let dayDifferenceComponents = calendar.dateComponents([.day], from: medicationDayStart, to: today)
            let dayDifference = dayDifferenceComponents.day ?? 0
            
            if dayDifference >= 2 {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: medication.timeToTake)
                if var newDueTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                 minute: timeComponents.minute ?? 0,
                                                 second: 0,
                                                 of: now) {
                    if newDueTime < now {
                        newDueTime = calendar.date(byAdding: .day, value: 1, to: newDueTime) ?? newDueTime
                    }
                    effectiveDueTime = newDueTime
                }
            }
            
            let isOverdue = effectiveDueTime < now && effectiveDueTime >= today
            return (isOverdue, false, effectiveDueTime)
        }
        
        let status1 = getMedicationStatus(med1)
        let status2 = getMedicationStatus(med2)
        
        // Priority order:
        // 1. Overdue medications first
        if status1.isOverdue && !status2.isOverdue {
            return true
        }
        if !status1.isOverdue && status2.isOverdue {
            return false
        }
        
        // 2. If both are overdue or both are not overdue, sort by due time
        if status1.isOverdue == status2.isOverdue {
            // 3. "As needed" medications go to the end
            if status1.isAsNeeded && !status2.isAsNeeded {
                return false
            }
            if !status1.isAsNeeded && status2.isAsNeeded {
                return true
            }
            
            // 4. Sort by effective due time
            return status1.effectiveDueTime < status2.effectiveDueTime
        }
        
        return false
    }
}

@ViewBuilder
fileprivate func MedicationsListContent(
    store: MedicationStore,
    showingAddSheet: Binding<Bool>,
    scrolledOffset: Binding<CGFloat>,
    horizontalInsets: CGFloat,
    showingLogSheetFor: Binding<Medication?>,
    selectedMedicationToEdit: Binding<Medication?>,
    medicationToArchive: Binding<Medication?>,
    showArchiveAlert: Binding<Bool>,
    showingArchivedSheet: Binding<Bool>,
    showingInteractionSheet: Binding<Bool>,
    isCheckingInteractions: Binding<Bool>,
    onCheckAllInteractions: @escaping () async -> Void,
    onAddMedication: @escaping () -> Void
) -> some View {
    ScrollView {
        VStack(spacing: 28) {
            // Enhanced header section
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Meds")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                    
                    Text("\(store.activeMedications.count) medication\(store.activeMedications.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Check interactions button
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        Task {
                            await onCheckAllInteractions()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(hex: "#F0F0E8"), location: 0.0),
                                            .init(color: Color(hex: "#E8E8E0"), location: 0.3),
                                            .init(color: Color(hex: "#DFDFD9"), location: 0.6),
                                            .init(color: Color(hex: "#C7C7BD"), location: 0.85),
                                            .init(color: Color(hex: "#B8B8AE"), location: 1.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .scaleEffect(isCheckingInteractions.wrappedValue ? 1.08 : 1.0)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.6),
                                                    Color.white.opacity(0.2),
                                                    Color.clear,
                                                    Color.black.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                            
                            if isCheckingInteractions.wrappedValue {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#404C42")))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color(hex: "#404C42"))
                            }
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isCheckingInteractions.wrappedValue)
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Add medication button (moved from floating position)
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        onAddMedication()
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(hex: "#F0F0E8"), location: 0.0),
                                            .init(color: Color(hex: "#E8E8E0"), location: 0.25),
                                            .init(color: Color(hex: "#DFDFD9"), location: 0.5),
                                            .init(color: Color(hex: "#C7C7BD"), location: 0.75),
                                            .init(color: Color(hex: "#B8B8AE"), location: 1.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0.3),
                                                    Color.clear,
                                                    Color.black.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                            
                            // Plus icon
                            ZStack {
                                // Horizontal bar
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#3A443D"))
                                    .frame(width: 20, height: 3)
                                
                                // Vertical bar
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#3A443D"))
                                    .frame(width: 3, height: 20)
                            }
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            
            // Enhanced medication cards section
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sortedMedications(store.activeMedications)) { med in
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
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.95))
                    ))
                }
            }
            

            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, horizontalInsets)
        .padding(.top, 16)
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

fileprivate struct FloatingActionButton: View {
    @Binding var showingAddSheet: Bool
    @Binding var showingArchivedSheet: Bool
    let hasArchivedMedications: Bool
    @Binding var isCheckingInteractions: Bool
    let onCheckAllInteractions: () async -> Void
    let onAddMedication: () -> Void
    @State private var isExpanded = false
    @State private var showBackdrop = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Enhanced backdrop with blur effect
            if showBackdrop {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture {
                        collapseMenu()
                    }
                    .transition(.opacity)
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Expanded action buttons
                        if isExpanded {
                            VStack(spacing: 12) {
                                // Archive button (always show)
                                expandedActionButton(
                                    icon: "archivebox.fill",
                                    text: "Archive",
                                    delay: 0.1
                                ) {
                                    HapticManager.shared.lightImpact()
                                    showingArchivedSheet = true
                                    collapseMenu()
                                }
                                
                                // Add medication button
                                expandedActionButton(
                                    icon: "plus.circle.fill",
                                    text: "Add Medication",
                                    delay: 0.05
                                ) {
                                    HapticManager.shared.lightImpact()
                                    onAddMedication()
                                    collapseMenu()
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        
                        // Main floating button
                        mainFloatingButton
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showBackdrop)
        .onAppear {
            // Removed tooltip auto-show logic
        }
    }
    
    // MARK: - Subviews
    


    
    private var mainFloatingButton: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            toggleMenu()
        }) {
            ZStack {
                // Perfect circle with enhanced 3D gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(hex: "#F0F0E8"), location: 0.0),
                                .init(color: Color(hex: "#E8E8E0"), location: 0.25),
                                .init(color: Color(hex: "#DFDFD9"), location: 0.5),
                                .init(color: Color(hex: "#C7C7BD"), location: 0.75),
                                .init(color: Color(hex: "#B8B8AE"), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        // Enhanced inner highlight with multiple layers
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(isExpanded ? 0.7 : 0.5),
                                        Color.white.opacity(0.3),
                                        Color.clear,
                                        Color.black.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .overlay(
                        // Subtle inner shadow for depth
                        Circle()
                            .stroke(
                                Color.black.opacity(0.1),
                                lineWidth: 0.8
                            )
                            .blur(radius: 0.8)
                            .offset(x: 1, y: 1)
                    )

                // More rectangular plus icon with enhanced animation
                ZStack {
                    if isExpanded {
                        // X mark for close
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "#3A443D"))
                    } else {
                        // Custom rectangular plus
                        ZStack {
                            // Horizontal bar (more rectangular)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(hex: "#3A443D"))
                                .frame(width: 24, height: 4)
                            
                            // Vertical bar (more rectangular)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(hex: "#3A443D"))
                                .frame(width: 4, height: 24)
                        }
                    }
                }
                .rotationEffect(.degrees(isExpanded ? 540 : 0))
                .scaleEffect(isExpanded ? 0.85 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isExpanded)
            }
            .shadow(color: Color.black.opacity(isExpanded ? 0.35 : 0.25), radius: isExpanded ? 15 : 12, x: 0, y: isExpanded ? 10 : 8)
            .shadow(color: Color(hex: "#2F352F").opacity(0.2), radius: 4, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.5), radius: 1, x: 0, y: -1)
            .scaleEffect(isExpanded ? 1.08 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isExpanded)
        }
        .buttonStyle(EnhancedScaleButtonStyle())
        .accessibilityLabel(isExpanded ? "Close actions menu" : "Show actions menu")
        .accessibilityHint("Double tap to \(isExpanded ? "close" : "open") the actions menu with options to add medications and view archive")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Helper Methods
    
    private func toggleMenu() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded.toggle()
            showBackdrop = isExpanded
        }

    }
    
    private func collapseMenu() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = false
            showBackdrop = false
        }
    }
    
    private func expandedActionButton(
        icon: String,
        text: String,
        delay: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#3A443D"))
                    .frame(width: 20)
                
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#3A443D"))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#E8E8E0"),
                        Color(hex: "#DFDFD9"),
                        Color(hex: "#C7C7BD"),
                        Color(hex: "#B8B8AE")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -1)
        }
        .buttonStyle(EnhancedScaleButtonStyle())
        .transition(.asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .bottom))
                .combined(with: .scale(scale: 0.1))
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(delay)),
            removal: .opacity
                .combined(with: .move(edge: .bottom))
                .combined(with: .scale(scale: 0.3))
                .animation(.spring(response: 0.4, dampingFraction: 0.9))
        ))
        .modifier(ShakeAnimationModifier(isExpanded: isExpanded, delay: delay))
    }
}

// Enhanced button style with better feedback
struct EnhancedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    HapticManager.shared.pulseButton()
                }
            }
    }
}

// Shake animation modifier for floating action buttons
struct ShakeAnimationModifier: ViewModifier {
    let isExpanded: Bool
    let delay: Double
    @State private var shakeOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: isExpanded) { _, newValue in
                if newValue {
                    // Start shake animation after the spring delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
                        // First intense shake
                        withAnimation(.easeInOut(duration: 0.06).repeatCount(7, autoreverses: true)) {
                            shakeOffset = 15
                        }
                        
                        // Reset shake offset after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            shakeOffset = 0
                        }
                    }
                } else {
                    shakeOffset = 0
                }
            }
    }
}

@ViewBuilder
func ArchivedMedicationsSheet(
    store: MedicationStore,
    showingArchivedSheet: Binding<Bool>
) -> some View {
    NavigationView {
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
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Enhanced Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Archived Medications")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        
                        Text("Medications you've archived can be restored anytime")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }
                    .padding(.top, 20)
                    
                    if store.archivedMedications.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                            
                            Text("No archived medications")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                            
                            Text("Medications you archive will appear here")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Archived medications list
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(store.archivedMedications) { med in
                                ArchivedMedicationCard(
                                    medication: med,
                                    onUnarchive: {
                                        HapticManager.shared.lightImpact()
                                        store.unarchiveMedication(med)
                                    }
                                )
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { 
                    HapticManager.shared.lightImpact()
                    showingArchivedSheet.wrappedValue = false 
                }
                .foregroundColor(Color(hex: "#C7C7BD"))
            }
        }
    }
}

@ViewBuilder
func ArchivedMedicationCard(
    medication: Medication,
    onUnarchive: @escaping () -> Void
) -> some View {
    HStack(spacing: 16) {
        // Medication icon
        Image(systemName: "pill.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
        
        // Medication info
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#E8E8E0"))
                .lineLimit(1)
            
            Text("\(medication.dosage) \(medication.dosageUnit) - \(medication.frequency)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
                .lineLimit(1)
            
            if let notes = medication.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#A8A8A0"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        
        Spacer()
        
        // Unarchive button
        Button(action: onUnarchive) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.bin")
                    .font(.system(size: 14, weight: .semibold))
                Text("Restore")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#404C42"))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#C7C7BD"))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
    let onAddMedication: () -> Void

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
                    EmptyMedicationsView(onAddMedication: onAddMedication)
                } else {
                    MedicationsListContent(
                        store: store,
                        showingAddSheet: $showingAddSheet,
                        scrolledOffset: $scrolledOffset,
                        horizontalInsets: horizontalInsets(for: UIScreen.main.bounds.width),
                        showingLogSheetFor: $showingLogSheetFor,
                        selectedMedicationToEdit: $selectedMedicationToEdit,
                        medicationToArchive: $medicationToArchive,
                        showArchiveAlert: $showArchiveAlert,
                        showingArchivedSheet: $showingArchivedSheet,
                        showingInteractionSheet: $showingInteractionSheet,
                        isCheckingInteractions: $isCheckingInteractions,
                        onCheckAllInteractions: onCheckAllInteractions,
                        onAddMedication: onAddMedication
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
// ScaleButtonStyle is now defined in UIComponents.swift

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
            return ("", .clear, false) // No status text when skipped, button shows "Skipped"
        case .overdue(let minutesPast):
            return ("Overdue by \(formatTimeText(minutes: minutesPast))", Color(hex: "#FFA726"), true)
        case .due(let minutesRemaining):
            return ("Due in \(formatTimeText(minutes: minutesRemaining))", Color(hex: "#D7CCC8"), true)
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
            return (iconName: "checkmark.circle.fill", text: "Taken", fgColor: Color(hex: "#4A5A4A"), bgColor: Color(hex: "#D7CCC8"))
        case .skipped:
            return (iconName: "xmark.circle.fill", text: "Skipped", fgColor: Color(hex: "#C62828"), bgColor: Color(hex: "#FFCDD2"))
        case .overdue(_), .due(_):
            return (iconName: "circle", text: "Take Now", fgColor: Color(hex: "#E0E0E0"), bgColor: Color.black.opacity(0.4))
        case .asNeeded: // Add .asNeeded case
            return (iconName: "circle", text: "Take Now", fgColor: Color(hex: "#E0E0E0"), bgColor: Color.black.opacity(0.4))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            medicationInfoSection
            Spacer()
            statusAndButtonSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showDetails.toggle()
            }
        }
    }
    
    // Enhanced medication information section (left side)
    private var medicationInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(medication.name)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Color(hex: "#F5F5F0"))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            Text(dosageString())
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            if let notes = medication.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#A8A8A0"))
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
    
    // Enhanced action button
    private var actionButton: some View {
        let properties = buttonProperties()
        
        return Button(action: {
            handleButtonTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: properties.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(properties.fgColor)
                
                Text(properties.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(properties.fgColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(properties.bgColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
                .padding(.top, 12)
            }
        }
        .background(
            // Enhanced gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#525E55"),
                    Color(hex: "#4A554D"),
                    Color(hex: "#424D45")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .overlay(enhancedBorderOverlay)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(commonFormatTime(medication.timeToTake))")
        .accessibilityHint(accessibilityHintText())
        .accessibilityValue(accessibilityValueText())
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
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .contextMenu {
            // Quick Log option
            Button {
                HapticManager.shared.successNotification()
                quickLogMedication(taken: true)
            } label: {
                Label("Log as Taken", systemImage: "checkmark.circle.fill")
            }
            
            // Quick Skip option
            Button {
                HapticManager.shared.warningNotification()
                quickLogMedication(taken: false)
            } label: {
                Label("Mark as Skipped", systemImage: "xmark.circle.fill")
            }
            
            Divider()
            
            // Edit option
            Button {
                HapticManager.shared.lightImpact()
                onEditTap()
            } label: {
                Label("Edit Medication", systemImage: "pencil.circle")
            }
            
            // Archive option (if available)
            if let archiveTap = onArchiveTap {
                Button(role: .destructive) {
                    HapticManager.shared.warningNotification()
                    archiveTap()
                } label: {
                    Label("Archive", systemImage: "archivebox.fill")
                }
            }
        }
    }
    
    // Enhanced border overlay with better visual feedback
    private var enhancedBorderOverlay: some View {
        let (borderColor, borderWidth): (Color, CGFloat)
        
        switch cycleStatus {
        case .taken:
            borderColor = Color(hex: "#D7CCC8")
            borderWidth = 2.0
        case .skipped:
            borderColor = Color(hex: "#FF6B6B")
            borderWidth = 2.0
        case .overdue(_):
            borderColor = Color(hex: "#FFB74D")
            borderWidth = 2.0
        case .due(_):
            // No colored border for due medications
            borderColor = Color.clear
            borderWidth = 0.0
        case .asNeeded:
            borderColor = Color.clear
            borderWidth = 0.0
        }
        
        return RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        borderColor.opacity(0.8),
                        borderColor.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: borderWidth
            )
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

    // Helper for accessibility value text
    private func accessibilityValueText() -> String {
        switch cycleStatus {
        case .taken:
            return "Taken today"
        case .skipped:
            return "Skipped today"
        case .due(let minutesRemaining):
            return minutesRemaining > 0 ? "Due in \(minutesRemaining) minutes" : "Due now"
        case .overdue(let minutesPast):
            return "Overdue by \(minutesPast) minutes"
        case .asNeeded:
            return "Take as needed"
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
    
    // Quick log medication function for context menu
    private func quickLogMedication(taken: Bool) {
        let now = Date()
        let quickLogNote = taken ? "Quick logged" : "Quick skipped"
        
        // Preserve existing medication notes by combining them with the quick log note
        var combinedNotes = quickLogNote
        if let existingNotes = medication.notes, !existingNotes.isEmpty {
            combinedNotes = "\(existingNotes)\n\n\(quickLogNote)"
        }
        
        store.logMedicationTaken(
            medication: medication,
            actualTime: now,
            notes: combinedNotes,
            skipped: !taken
        )
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
        VStack(alignment: .leading, spacing: 20) {
            // Enhanced detail cards with better visual hierarchy
            VStack(alignment: .leading, spacing: 16) {
                detailCard(
                    icon: "repeat.circle.fill", 
                    label: "Frequency", 
                    value: medication.frequency, 
                    iconColor: Color(hex: "#D7CCC8")
                )
                
                // Only show reminder time and notifications for non-"As needed" medications
                if medication.frequency != "As needed" {
                    detailCard(
                        icon: "alarm.fill", 
                        label: "Reminder Time", 
                        value: reminderTimesString, 
                        iconColor: Color(hex: "#FFB74D")
                    )
                    
                    detailCard(
                        icon: notificationsEnabled ? "bell.fill" : "bell.slash.fill", 
                        label: "Notifications", 
                        value: notificationsEnabled ? "Enabled" : "Disabled", 
                        valueColor: notificationsEnabled ? Color(hex: "#D7CCC8") : Color(hex: "#FF6B6B"), 
                        iconColor: notificationsEnabled ? Color(hex: "#D7CCC8") : Color(hex: "#FF6B6B")
                    )
                }
                
                if let notes = medication.notes, !notes.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Text(notes)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#606A63").opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }

            // Enhanced action buttons with improved styling
            HStack(spacing: 12) {
                Button(action: onEditTap) {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                        Text("Edit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#E8E8E0"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.4),
                                Color.black.opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#606A63").opacity(0.4),
                                        Color(hex: "#606A63").opacity(0.2)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(ScaleButtonStyle())

                if let archiveTap = onArchiveTap {
                    Button(action: archiveTap) {
                        HStack(spacing: 10) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFB74D"))
                            Text("Archive")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFB74D"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.3)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#FFB74D").opacity(0.4),
                                            Color(hex: "#FFB74D").opacity(0.2)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func detailCard(
        icon: String, 
        label: String, 
        value: String, 
        valueColor: Color = Color(hex: "#E8E8E0"), 
        lineLimit: Int? = 1,
        iconColor: Color = Color(hex: "#C7C7BD")
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Enhanced icon with background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(valueColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(lineLimit)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#606A63").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// Extension to convert ShapeStyle types to AnyShapeStyle
extension ShapeStyle {
    func anyShapeStyle() -> AnyShapeStyle {
        return AnyShapeStyle(self)
    }
}
