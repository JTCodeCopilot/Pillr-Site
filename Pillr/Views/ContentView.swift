//
//  ContentView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
// 

import SwiftUI
import WebKit

// MARK: - Global Background Definition
extension Color {
    static let pillrNavy = Color.black
    static let pillrSoftBlue = Color.black
    static let pillrDeepBlue = Color.black
}

extension LinearGradient {
    static let pillrBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "#404C42"),  // Solid background color
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

// Alternative background accessor for direct color use
extension View {
    func pillrNavyBackground() -> some View {
        self.background(LinearGradient.pillrBackground)
    }
}

// MARK: - Color Extension for Theme Colors
extension Color {
    static var pillrAccent: Color {
        return Color(hex: "#F5F5F5") // Tan accent color
    }
    
    static var pillrSecondary: Color {
        return Color(hex: "#F5F5F5") // Tan secondary color
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glass Effect Extensions

extension View {
    func glassCircleBackground(diameter: CGFloat, opacity: Double = 0.98) -> some View {
        self
            .background(
                Circle()
                    .fill(Color.white.opacity(opacity))
                    .blur(radius: 30)
                    .background(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .compositingGroup()
                    .shadow(color: Color.white.opacity(0.25), radius: 8, x: 0, y: 0)
            )
            .clipShape(Circle())
    }
    
    func glassRectBackground(cornerRadius: CGFloat = 18, opacity: Double = 0.98) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(opacity))
                    .blur(radius: 25)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .compositingGroup()
                    .shadow(color: Color.white.opacity(0.25), radius: 6, x: 0, y: 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// Custom transition for tab view
extension AnyTransition {
    static var moveAndFade: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }
    
    static var smoothTab: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing).animation(.easeInOut(duration: 0.3))),
            removal: .opacity.combined(with: .move(edge: .leading).animation(.easeInOut(duration: 0.3)))
        )
    }
}

struct ContentView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var storeManager: StoreManager
    @State private var showingPopoutMenu = false
    @State private var showingLogView = false
    @State private var showingSettingsView = false
    @State private var showingInteractionAI = false
    @State private var showingMedicationSelectionSheet = false
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    @State private var showingPrivacyPolicyWebView = false
    @State private var showingFeedbackWebView = false
    @State private var showingContactUsWebView = false
    @State private var showingAddMedicationSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dynamic Background
                LinearGradient.pillrBackground
                    .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                
                // Add subtle animated background shapes for depth
                ZStack {
                    // Single large solid background
                    Rectangle()
                        .fill(Color(hex: "#404C42"))
                        .ignoresSafeArea()
                    
                    // Top navbar area
                    Rectangle()
                        .fill(Color(hex: "#404C42"))
                        .frame(height: geometry.safeAreaInsets.top + 44)
                        .ignoresSafeArea(edges: .top)
                }

                // 2. Main Content Area - Always show MedicationsListView
                // Main content without bottom bar
                MedicationsListView()
                    .scrollContentBackground(.hidden)
                    .padding(.top, geometry.safeAreaInsets.top * 0.5)
                    .frame(maxHeight: .infinity)
                
                // Centered Menu Button at Bottom
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MenuButton(showingPopoutMenu: $showingPopoutMenu)
                            .padding(.bottom, geometry.safeAreaInsets.bottom)
                        Spacer()
                    }
                }
                
                // Popout Menu Overlay - Direct rendering with no animation wrapper
                if showingPopoutMenu {
                        PopoutMenuOverlay(
                            showingPopoutMenu: $showingPopoutMenu,
                            showingLogView: $showingLogView,
                            showingSettingsView: $showingSettingsView,
                            showingMedicationSelectionSheet: $showingMedicationSelectionSheet,
                            showingAddMedicationSheet: $showingAddMedicationSheet,
                            isPremiumUser: userSettings.isPremiumUser,
                            onShowPremiumUpgrade: {
                                showingPremiumUpgrade = true
                            },
                            geometry: geometry
                        )
                    }
                }
            }
        .preferredColorScheme(.dark)
        .accessibilityAddTraits(.isButton)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pillr - Your Personal Medication Tracker")
        .accessibilityHint("Manage your medications, track doses, and get reminders")
        .accessibilityAction(.default) {
            // Default action for main view
        }
        // No animations on sheet presentations for faster response
        .sheet(isPresented: $showingLogView) {
            MedicationLogViewSheet(store: store, userSettings: userSettings, isPresented: $showingLogView)
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsViewSheet(userSettings: userSettings, isPresented: $showingSettingsView)
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $showingMedicationSelectionSheet) {
            MedicationInteractionSelectionSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $showingInteractionHistory) {
            InteractionHistoryView()
        }
        .sheet(isPresented: $showingPrivacyPolicyWebView) {
            EmbeddedWebView(url: URL(string: "https://tally.so/r/3yR6M4")!, title: "Privacy Policy", isPresented: $showingPrivacyPolicyWebView)
        }
        .sheet(isPresented: $showingFeedbackWebView) {
            EmbeddedWebView(url: URL(string: "https://tally.so/r/w2yeXV")!, title: "Feedback", isPresented: $showingFeedbackWebView)
        }
        .sheet(isPresented: $showingContactUsWebView) {
            EmbeddedWebView(url: URL(string: "https://tally.so/r/3qMdL7")!, title: "Contact Us", isPresented: $showingContactUsWebView)
        }
        .sheet(isPresented: $showingAddMedicationSheet) {
            NavigationView {
                AddMedicationView(onFinish: { showingAddMedicationSheet = false })
                    .environmentObject(store)
                    .environmentObject(userSettings)
            }
        }
    }
}

// MARK: - Menu Button Component
struct MenuButton: View {
    @Binding var showingPopoutMenu: Bool
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            showingPopoutMenu.toggle() // No animation on toggle for immediate response
        }) {
            ZStack {
                // Outer glow ring when menu is open
                if showingPopoutMenu {
                    Circle()
                        .stroke(Color(hex: "#F5F1E8").opacity(0.4), lineWidth: 2)
                        .frame(width: 76, height: 76)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .opacity(pulseAnimation ? 0.3 : 0.6)
                }
                
                // Main floating button with glass background and shadows
                Circle()
                    .frame(width: 60, height: 60)
                    .glassCircleBackground(diameter: 60, opacity: 0.98)
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .scaleEffect(showingPopoutMenu ? 1.08 : 1.0)
                
                // Icon with no animation and light color on glass
                if showingPopoutMenu {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.95))
                } else {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#525E55"))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingPopoutMenu) // Faster animation response
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
        .onAppear {
            if showingPopoutMenu {
                pulseAnimation = true
            }
        }
        .onChange(of: showingPopoutMenu) { newValue in
            if newValue {
                pulseAnimation = true
            } else {
                pulseAnimation = false
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Popout Menu Overlay
struct PopoutMenuOverlay: View {
    @Binding var showingPopoutMenu: Bool
    @Binding var showingLogView: Bool
    @Binding var showingSettingsView: Bool
    @Binding var showingMedicationSelectionSheet: Bool
    @Binding var showingAddMedicationSheet: Bool
    let isPremiumUser: Bool
    let onShowPremiumUpgrade: () -> Void
    let geometry: GeometryProxy
    @State private var animateItems = false
    
    var body: some View {
        ZStack {
            // Dark frosted background overlay with immediate appearance
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial, in: Rectangle())
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeOut(duration: 0.15))) // Faster fade in
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { // Faster dismissal
                        showingPopoutMenu = false
                    }
                }
            
            // Menu items with faster staggered animation
            VStack(spacing: 16) {
                Spacer()
                
                VStack(spacing: 16) {
                    // 1. Add Medication button
                    MenuItemButton(
                        icon: "pills",
                        title: "Add Medication",
                        delay: 0.0,
                        animateItems: animateItems,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingPopoutMenu = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showingAddMedicationSheet = true
                            }
                        }
                    )
                    
                    // 2. Interaction AI button
                    MenuItemButton(
                        icon: "hourglass",
                        title: "Interaction AI",
                        delay: 0.05,
                        animateItems: animateItems,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingPopoutMenu = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                if isPremiumUser {
                                    showingMedicationSelectionSheet = true
                                } else {
                                    onShowPremiumUpgrade()
                                }
                            }
                        }
                    )
                    
                    // 3. Medication History button
                    MenuItemButton(
                        icon: "checklist.checked",
                        title: "Medication History",
                        delay: 0.1,
                        animateItems: animateItems,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingPopoutMenu = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showingLogView = true
                            }
                        }
                    )
                    
                    // 5. Settings button
                    MenuItemButton(
                        icon: "gearshape",
                        title: "Settings",
                        delay: 0.2,
                        animateItems: animateItems,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingPopoutMenu = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showingSettingsView = true
                            }
                        }
                    )
                }
                .padding(.bottom, 70 + geometry.safeAreaInsets.bottom)
            }
        }
        .transition(.identity) // Keep identity transition for immediate appearance
        .onAppear {
            // Trigger menu items animation immediately on appear
            animateItems = true
        }
        .onDisappear {
            animateItems = false
        }
    }
}

// MARK: - Menu Item Button
struct MenuItemButton: View {
    let icon: String
    let title: String
    let delay: Double
    let animateItems: Bool
    let action: () -> Void
    @State private var isPressed = false
    @State private var hasAppeared = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#525E55"))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassRectBackground(cornerRadius: 20, opacity: 1)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
            .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? -0.05 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 40)
        .scaleEffect(hasAppeared ? 1.0 : 0.7) // Start from a larger scale for faster appearance
        .opacity(hasAppeared ? 1.0 : 0.0)
        .offset(y: hasAppeared ? 0 : 15) // Reduced offset distance for faster appearance
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed) // Faster button press
        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay), value: hasAppeared) // Faster item appearance
        .onChange(of: animateItems) { newValue in
            // Use dispatchqueue to slightly stagger the appearance
            if newValue {
                DispatchQueue.main.async {
                    hasAppeared = true
                }
            } else {
                hasAppeared = false
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Sheet Wrapper Views
struct MedicationLogViewSheet: View {
    @ObservedObject var store: MedicationStore
    @ObservedObject var userSettings: UserSettings
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            MedicationLogContentView()
                .environmentObject(store)
                .environmentObject(userSettings)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                    }
                }
        }
    }
}

struct SettingsViewSheet: View {
    @ObservedObject var userSettings: UserSettings
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            SettingsContentView()
                .environmentObject(userSettings)
                .environmentObject(storeManager)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                        }
                    }
                }
        }
    }
}

// MARK: - Content Views (without NavigationView)
struct MedicationLogContentView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingCalendar = false
    @State private var selectedDate: Date = Date()
    @State private var selectedMedicationFilter: String = "All"
    
    // Group logs by date
    private var groupedLogs: [Date: [MedicationLog]] {
        let calendar = Calendar.current
        var result = [Date: [MedicationLog]]()
        
        // Filter logs based on selected medication and exclude skipped logs
        let filteredLogs = store.logs.filter { log in
            let medicationMatch = selectedMedicationFilter == "All" || log.medicationName == selectedMedicationFilter
            return !log.skipped && medicationMatch
        }

        for log in filteredLogs {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.takenAt)
            if let date = calendar.date(from: dateComponents) {
                if result[date] == nil {
                    result[date] = [log]
                } else {
                    result[date]?.append(log)
                }
            }
        }
        
        // Sort logs within each day by time (most recent first)
        for (date, logs) in result {
            result[date] = logs.sorted { $0.takenAt > $1.takenAt }
        }
        
        return result
    }
    
    // Sort dates in descending order (most recent first)
    private var sortedDates: [Date] {
        return groupedLogs.keys.sorted(by: >)
    }
    
    // Filter logs for the selected date
    private var logsForSelectedDate: [MedicationLog] {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        guard let startOfDay = calendar.date(from: dateComponents) else { return [] }
        
        return groupedLogs[startOfDay] ?? []
    }
    
    // Get unique medication names for filter
    private var uniqueMedicationNames: [String] {
        let names = Set(store.logs.filter { !$0.skipped }.map { $0.medicationName })
        return ["All"] + Array(names).sorted()
    }
    
    // Date formatter for section headers
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced header with filter options
                    VStack(spacing: 12) {
                        HStack {
                            Text("History")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            Spacer()
                            
                            // Export button
                            Button(action: {
                                shareCSV()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 16))
                                    Text("Export")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#525E55"))
                                .cornerRadius(20)
                            }
                            
                            // Filter button
                            Menu {
                                Picker("Filter by Medication", selection: $selectedMedicationFilter) {
                                    ForEach(uniqueMedicationNames, id: \.self) { medicationName in
                                        Text(medicationName).tag(medicationName)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 16, weight: .semibold))

                                    Text(selectedMedicationFilter == "All" ? "All" : selectedMedicationFilter)
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .opacity(0.6)
                                }
                                .foregroundColor(Color(hex: "#525E55"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(RoundedRectangle(cornerRadius: 20))
                                .glassRectBackground(cornerRadius: 20, opacity: 1)
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                                .shadow(color: Color.white.opacity(1), radius: 1, x: 0, y: 1)
                            }
                        }
                        
                        // Stats row
                        HStack(spacing: 16) {
                            StatCard(title: "Total Doses", value: "\(store.logs.filter { !$0.skipped }.count)", icon: "pills.fill")
                            StatCard(title: "This Week", value: "\(logsThisWeek)", icon: "calendar")
                            StatCard(title: "Streak", value: "\(currentStreak) days", icon: "flame.fill")
                        }
                        
                        // Selected date indicator (if not today)
                        if !Calendar.current.isDateInToday(selectedDate) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                
                                Text(dateFormatter.string(from: selectedDate))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(Color(hex: "#404C42"))
                    .zIndex(1)
                    
                    // Content area
                    ZStack {
                        if store.logs.filter({ !$0.skipped }).isEmpty {
                            EmptyHistoryView()
                        } else if logsForSelectedDate.isEmpty && !Calendar.current.isDateInToday(selectedDate) {
                            NoLogsForDateView(date: selectedDate, dateFormatter: dateFormatter)
                        } else {
                            LogsContentView(
                                selectedDate: selectedDate,
                                sortedDates: sortedDates,
                                groupedLogs: groupedLogs,
                                logsForSelectedDate: logsForSelectedDate,
                                store: store
                            )
                        }
                    }
                }
                .padding(.horizontal, horizontalInsets(for: geometry))
                
                // Floating buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Calendar button
                            FloatingButton(
                                icon: "calendar",
                                action: { showingCalendar = true }
                            )
                            
                            // Today button (only show if not on today)
                            if !Calendar.current.isDateInToday(selectedDate) {
                                FloatingButton(
                                    icon: "house.fill",
                                    action: { selectedDate = Date() }
                                )
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 50)
                }
                .zIndex(2)
                
                // Date Picker Popover
                if showingCalendar {
                    HistoryDatePickerOverlay(
                        selectedDate: $selectedDate,
                        showingCalendar: $showingCalendar,
                        geometry: geometry
                    )
                    .zIndex(4)
                }
            }
        }
    }
    
    // Calculate logs this week
    private var logsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return store.logs.filter { log in
            !log.skipped && log.takenAt >= weekAgo && log.takenAt <= now
        }.count
    }
    
    // Calculate current streak
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        while true {
            let hasLogForDate = store.logs.contains { log in
                !log.skipped && calendar.isDate(log.takenAt, inSameDayAs: currentDate)
            }
            
            if hasLogForDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    // Calculate proper insets based on screen size
    private func horizontalInsets(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            return max((geometry.size.width - 650) / 2, 16)
        }
        return 16
    }
    
    // MARK: - Export Functionality
    // Function to export medication logs as plain text
    private func exportMedicationLogsAsText() -> String {
        // Create a readable text format
        var textContent = "MEDICATION HISTORY\n"
        textContent += "=================\n\n"
        
        // Date formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        // Filter logs based on selected medication
        let filteredLogs = store.logs.filter { log in
            selectedMedicationFilter == "All" || log.medicationName == selectedMedicationFilter
        }
        
        // Group logs by date for better readability
        let calendar = Calendar.current
        var groupedByDate: [Date: [MedicationLog]] = [:]
        
        for log in filteredLogs {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.takenAt)
            if let date = calendar.date(from: dateComponents) {
                if groupedByDate[date] == nil {
                    groupedByDate[date] = [log]
                } else {
                    groupedByDate[date]?.append(log)
                }
            }
        }
        
        // Sort dates in descending order (most recent first)
        let sortedDates = groupedByDate.keys.sorted(by: >)
        
        // Add content for each date
        for date in sortedDates {
            textContent += "\(dateFormatter.string(from: date))\n"
            textContent += String(repeating: "-", count: dateFormatter.string(from: date).count) + "\n\n"
            
            // Sort logs for this date by time
            let logsForDate = groupedByDate[date]?.sorted(by: { $0.takenAt > $1.takenAt }) ?? []
            
            for log in logsForDate {
                let medicationName = log.medicationName
                let time = timeFormatter.string(from: log.takenAt)
                
                // Get medication details if available
                let medication = store.medications.first { $0.id == log.medicationID }
                let dosage = medication != nil ? "\(medication!.dosage) \(medication!.dosageUnit)" : ""
                
                textContent += "• \(medicationName) - \(dosage) at \(time)\n"
                
                // Add status (skipped or taken)
                if log.skipped {
                    textContent += "  Status: Skipped\n"
                } else {
                    textContent += "  Status: Taken\n"
                }
                
                // Add notes if present
                if let notes = log.notes, !notes.isEmpty {
                    textContent += "  Notes: \(notes)\n"
                }
                
                textContent += "\n"
            }
        }
        
        // Add summary at the end
        textContent += "===== SUMMARY =====\n"
        textContent += "Total medications: \(filteredLogs.filter { !$0.skipped }.count) taken, \(filteredLogs.filter { $0.skipped }.count) skipped\n"
        textContent += "Generated on: \(dateFormatter.string(from: Date()))\n"
        
        return textContent
    }

    // Function to create and share the text file
    private func shareCSV() {
        let textContent = exportMedicationLogsAsText()
        
        // Create a temporary file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "MedicationHistory_\(dateFormatter.string(from: Date())).txt"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            
            do {
                try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Share the file
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                
                // Ensure iPad gets a popover
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = UIApplication.shared.windows.first?.rootViewController?.view
                    popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                // Present the share sheet
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    
                    // If presented from a sheet, find the correct presenting controller
                    var presentingController = rootViewController
                    while let presented = presentingController.presentedViewController {
                        presentingController = presented
                    }
                    
                    presentingController.present(activityVC, animated: true, completion: nil)
                }
            } catch {
                print("Error writing text file: \(error)")
            }
        }
    }
}

struct SettingsContentView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var storeManager: StoreManager
    @State private var showingPremiumUpgrade = false
    @State private var showingInteractionHistory = false
    @State private var showingPrivacyPolicyWebView = false
    @State private var showingFeedbackWebView = false
    @State private var showingContactUsWebView = false
    @State private var currentWebViewURL: URL?
    @State private var webViewTitle: String = ""
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "#404C42")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color.pillrAccent)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    appSettingsSection
                    
                    aiSettingsSection
                    
                    supportLinksSection
                    
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(storeManager)
        }
        .sheet(isPresented: $showingInteractionHistory) {
            InteractionHistoryView()
        }
        .sheet(isPresented: $showingPrivacyPolicyWebView) {
            EmbeddedWebView(url: URL(string: "https://tally.so/r/3yR6M4")!, title: "Privacy Policy", isPresented: $showingPrivacyPolicyWebView)
        }
        .sheet(isPresented: $showingFeedbackWebView) {
            EmbeddedWebView(url: URL(string: "https://tally.so/r/w2yeXV")!, title: "Feedback", isPresented: $showingFeedbackWebView)
        }
        .sheet(isPresented: $showingContactUsWebView) {
            EmbeddedWebView(url: URL(string: "https://tally.so/r/3qMdL7")!, title: "Contact Us", isPresented: $showingContactUsWebView)
        }
        .task {
            // Load products and update purchased products when the view appears
            await storeManager.loadProducts()
            await storeManager.updatePurchasedProducts()
        }
    }
    
    // Computed property for App Settings section
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#525E55"))
                Text("App Settings")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            Divider()
                .background(Color(hex: "#525E55").opacity(0.15))
            
            // Interaction History
            Button(action: {
                showingInteractionHistory = true
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interaction History")
                            .foregroundColor(Color(hex: "#525E55"))
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("View and manage your interaction checks")
                            .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                            .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // Computed property for AI Settings section
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#525E55"))
                Text("AI Features")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#525E55").opacity(0.15))
            
            // Premium Subscription
            if OpenAIService.shared.isPremiumUser() {
                // Non-tappable premium status display
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(hex: "#D4A017"))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Active")
                            .foregroundColor(Color(hex: "#525E55"))
                            .font(.system(size: 16, weight: .medium))
                        
                        if let subscriptionType = OpenAIService.shared.getSubscriptionType() {
                            Text("\(subscriptionType.capitalized) subscription")
                                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                                .font(.system(size: 14))
                        } else {
                            Text("AI-powered interaction checking enabled")
                                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                                .font(.system(size: 14))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16))
                }
                .padding(.vertical, 4)
            } else {
                // Tappable upgrade button
                Button(action: {
                    showingPremiumUpgrade = true
                }) {
                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundColor(Color(hex: "#525E55"))
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .foregroundColor(Color(hex: "#525E55"))
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Unlock AI-powered medication analysis")
                                .foregroundColor(Color(hex: "#525E55").opacity(0.7))
                                .font(.system(size: 14))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // Computed property for Support Links section
    private var supportLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#525E55"))
                Text("Support & Resources")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#525E55"))
                Spacer()
            }
            
            Divider()
                .background(Color(hex: "#525E55").opacity(0.15))
            
            // Privacy Policy Link
            Button(action: {
                showingPrivacyPolicyWebView = true
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    Text("Privacy Policy")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Feedback Link
            Button(action: {
                showingFeedbackWebView = true
            }) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    Text("Feedback")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Contact Us Link
            Button(action: {
                showingContactUsWebView = true
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color(hex: "#525E55"))
                        .frame(width: 20)
                    
                    Text("Contact Us")
                        .foregroundColor(Color(hex: "#525E55"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#525E55").opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .glassRectBackground(cornerRadius: 20, opacity: 1)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .shadow(color: Color.white.opacity(1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Embedded WebView
struct EmbeddedWebView: View {
    let url: URL
    let title: String
    @Binding var isPresented: Bool
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                VStack {
                    WebView(url: url, isLoading: $isLoading)
                        .overlay(
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#C7C7BD")))
                                        .scaleEffect(1.5)
                                        .frame(width: 50, height: 50)
                                        .background(Color(hex: "#404C42").opacity(0.7))
                                        .cornerRadius(10)
                                }
                            }
                        )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// UIKit WebView wrapped for SwiftUI
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicationStore())
            .environmentObject(UserSettings.shared)
    }
}

// MARK: - HistoryDatePickerOverlay (renamed to avoid redeclaration)
struct HistoryDatePickerOverlay: View {
    @Binding var selectedDate: Date
    @Binding var showingCalendar: Bool
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            // Dimmed background to improve contrast
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    showingCalendar = false
                }

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button(action: {
                        showingCalendar = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
                .padding(.horizontal)
                .padding(.top, geometry.safeAreaInsets.top + 10)

                // Themed calendar with solid background for legibility
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Color(hex: "#C7C7BD"))
                .environment(\.colorScheme, .dark)
                .padding(12)
                .background(Color(hex: "#404C42"))
                .cornerRadius(12)

                Spacer()
            }
            .padding(.bottom, geometry.safeAreaInsets.bottom)
            .frame(maxWidth: 350)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#404C42"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(.horizontal)
        }
    }
}
