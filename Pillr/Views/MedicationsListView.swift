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
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                            showingArchivedSheet: $showingArchivedSheet
                        )
                    }
                }
            }
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
    showingArchivedSheet: Binding<Bool>
) -> some View {
    ScrollView {
        VStack(spacing: 24) {
            HStack {
                Text("Currently Taking")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.activeMedications.sorted(by: { $0.timeToTake < $1.timeToTake })) { med in
                    MedicationRow(
                        medication: med,
                        onLogTap: { showingLogSheetFor.wrappedValue = med },
                        onEditTap: { selectedMedicationToEdit.wrappedValue = med },
                        onArchiveTap: {
                            medicationToArchive.wrappedValue = med
                            showArchiveAlert.wrappedValue = true
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            if !store.archivedMedications.isEmpty {
                Button(action: { showingArchivedSheet.wrappedValue = true }) {
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
                // 3D Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#EDEDE3"), // Top highlight
                        Color(hex: "#C7C7BD"), // Middle
                        Color(hex: "#A6A69A")  // Bottom shadow
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                // Top white highlight
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.35), Color.clear]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: 68, height: 68)
                    .offset(y: -8)
                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "#404C42"))
            }
            .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 8)
            .shadow(color: Color(hex: "#2F352F").opacity(0.18), radius: 2, x: 0, y: 1)
        }
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

private extension MedicationsListView {
    func horizontalInsets(for width: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular && width > 768 {
            return max((width - 650) / 2, 16)
        }
        return 16
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

fileprivate struct MedicationRowDetailsView: View {
    let medication: Medication
    let onEditTap: () -> Void
    let onArchiveTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(Color(hex: "#C7C7BD").opacity(0.3))
                .padding(.horizontal, 12)
            
            VStack(alignment: .leading, spacing: 8) {
                // Section title
                Text("DETAILS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    .padding(.bottom, 4)
                
                // Primary time
                HStack {
                    Text("Primary time:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    
                    Text(commonFormatTime(medication.timeToTake))
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
                
                // Additional times if any
                if !medication.reminderTimes.isEmpty {
                    Text("Reminder times:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    
                    ForEach(0..<medication.reminderTimes.count, id: \.self) { index in
                        Text("• \(commonFormatTime(medication.reminderTimes[index]))")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.leading, 8)
                    }
                }
                
                // Pill count information if available
                if let pillCount = medication.pillCount {
                    HStack {
                        Text("Remaining:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        
                        Text("\(pillCount) pills")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    
                    HStack {
                        Text("Per dose:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        
                        Text("\(medication.pillsPerDose) \(medication.pillsPerDose == 1 ? "pill" : "pills")")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    
                    if let threshold = medication.refillThreshold {
                        HStack {
                            Text("Refill alert:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                        
                            Text("When below \(threshold) pills")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            // Action buttons in expanded section
            HStack(spacing: 12) {
                Button(action: onEditTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                        Text("Edit")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#404C42").opacity(0.7))
                    .cornerRadius(8)
                }
                if let onArchiveTap = onArchiveTap {
                    Button(action: onArchiveTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 14))
                            Text("Archive")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(hex: "#404C42").opacity(0.7))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
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
    
    // Check if the medication was taken today
    private var wasTakenToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return store.logs.contains { log in
            log.medicationID == medication.id &&
            calendar.isDate(calendar.startOfDay(for: log.takenAt), inSameDayAs: today)
        }
    }
    
    // Get next due time status
    private var timeStatus: String {
        let now = Date()
        let minutes = Calendar.current.dateComponents([.minute], from: now, to: medication.timeToTake).minute ?? 0
        
        if minutes < 0 {
            let absMinutes = abs(minutes)
            if absMinutes < 60 {
                return "Overdue by \(absMinutes) min\(absMinutes == 1 ? "" : "s")"
            } else {
                let hours = absMinutes / 60
                let remMinutes = absMinutes % 60
                if remMinutes == 0 {
                    return "Overdue by \(hours) \(hours == 1 ? "hour" : "hours")"
                } else {
                    return "Overdue by \(hours)h \(remMinutes)m"
                }
            }
        } else if minutes < 60 {
            return "Due in \(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let remMinutes = minutes % 60
            if remMinutes == 0 {
                return "Due in \(hours) \(hours == 1 ? "hour" : "hours")"
            } else {
                return "Due in \(hours)h \(remMinutes)m"
            }
        }
    }
    
    // Get color for time status
    private var timeStatusColor: Color {
        let now = Date()
        let minutes = Calendar.current.dateComponents([.minute], from: now, to: medication.timeToTake).minute ?? 0
        
        if minutes < 0 {
            return .red
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Text("\(medication.dosage) - \(medication.frequency)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    
                    if let notes = medication.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 20) {
                    Text(timeStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(timeStatusColor)
                    
                    Button(action: {
                        if !wasTakenToday {
                            HapticManager.shared.successNotification()
                        } else {
                            HapticManager.shared.lightImpact()
                        }
                        onLogTap()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: wasTakenToday ? "checkmark" : "circle")
                                .font(.system(size: 25))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            Text(wasTakenToday ? "Taken" : "Take Now")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            wasTakenToday ?
                                Color(hex: "#C7C7BD").opacity(0.1) :
                                Color.black.opacity(0.3)
                        )
                        .cornerRadius(15)
                    }
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
            }
            
            if showDetails {
                MedicationRowDetailsView(
                    medication: medication,
                    onEditTap: onEditTap,
                    onArchiveTap: onArchiveTap
                )
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    wasTakenToday ? Color(hex: "#C7C7BD").opacity(0.3) : Color(hex: "#C7C7BD").opacity(0.1),
                    lineWidth: 0.5
                )
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                .padding(.top, 30)
                .padding(.trailing, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(commonFormatTime(medication.timeToTake))")
        .accessibilityHint(wasTakenToday ? "Already taken today. Double tap to expand details." : "Double tap to log as taken or expand details.")
        .accessibilityAction(.default) {
            if !wasTakenToday {
                onLogTap()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
            }
        }
        .accessibilityAction(named: wasTakenToday ? "View Details" : "View Details Without Logging") {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        }
    }
}

// Extension to convert ShapeStyle types to AnyShapeStyle
extension ShapeStyle {
    func anyShapeStyle() -> AnyShapeStyle {
        return AnyShapeStyle(self)
    }
}
