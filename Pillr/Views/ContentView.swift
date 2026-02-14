//
//  ContentView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
// 

import SwiftUI
import UIKit
import WebKit

struct AppThemePalette {
    let backgroundPrimary: String
    let backgroundSecondary: String
    let surfacePrimary: String
    let surfaceSecondary: String
    let border: String
    let divider: String
    let textPrimary: String
    let textSecondary: String
    let textMuted: String
    let iconPrimary: String
    let iconSecondary: String
    let inputBackground: String
    let inputBorder: String
    let inputPlaceholder: String
    let buttonPrimaryBackground: String
    let buttonPrimaryForeground: String
    let buttonSecondaryBackground: String
    let buttonSecondaryForeground: String
    let interactivePressed: String
    let interactiveDisabledBackground: String
    let interactiveDisabledForeground: String
    let success: String
    let warning: String
    let error: String
    let link: String
    let navigationBackground: String
    let navigationTitle: String
    let tabBarBackground: String

    var backgroundPrimaryColor: Color { Color(hexLiteral: backgroundPrimary) }
    var backgroundSecondaryColor: Color { Color(hexLiteral: backgroundSecondary) }
    var surfacePrimaryColor: Color { Color(hexLiteral: surfacePrimary) }
    var surfaceSecondaryColor: Color { Color(hexLiteral: surfaceSecondary) }
    var borderColor: Color { Color(hexLiteral: border) }
    var dividerColor: Color { Color(hexLiteral: divider) }
    var textPrimaryColor: Color { Color(hexLiteral: textPrimary) }
    var textSecondaryColor: Color { Color(hexLiteral: textSecondary) }
    var textMutedColor: Color { Color(hexLiteral: textMuted) }
    var iconPrimaryColor: Color { Color(hexLiteral: iconPrimary) }
    var iconSecondaryColor: Color { Color(hexLiteral: iconSecondary) }
    var inputBackgroundColor: Color { Color(hexLiteral: inputBackground) }
    var inputBorderColor: Color { Color(hexLiteral: inputBorder) }
    var inputPlaceholderColor: Color { Color(hexLiteral: inputPlaceholder) }
    var buttonPrimaryBackgroundColor: Color { Color(hexLiteral: buttonPrimaryBackground) }
    var buttonPrimaryForegroundColor: Color { Color(hexLiteral: buttonPrimaryForeground) }
    var buttonSecondaryBackgroundColor: Color { Color(hexLiteral: buttonSecondaryBackground) }
    var buttonSecondaryForegroundColor: Color { Color(hexLiteral: buttonSecondaryForeground) }
    var interactivePressedColor: Color { Color(hexLiteral: interactivePressed) }
    var interactiveDisabledBackgroundColor: Color { Color(hexLiteral: interactiveDisabledBackground) }
    var interactiveDisabledForegroundColor: Color { Color(hexLiteral: interactiveDisabledForeground) }
    var successColor: Color { Color(hexLiteral: success) }
    var warningColor: Color { Color(hexLiteral: warning) }
    var errorColor: Color { Color(hexLiteral: error) }
    var linkColor: Color { Color(hexLiteral: link) }
    var navigationBackgroundColor: Color { Color(hexLiteral: navigationBackground) }
    var navigationTitleColor: Color { Color(hexLiteral: navigationTitle) }
    var tabBarBackgroundColor: Color { Color(hexLiteral: tabBarBackground) }

    static let light = AppThemePalette(
        backgroundPrimary: "#404C42",
        backgroundSecondary: "#3A443D",
        surfacePrimary: "#4C584F",
        surfaceSecondary: "#5B695D",
        border: "#606A63",
        divider: "#A0A69B",
        textPrimary: "#F5F7F4",
        textSecondary: "#E0E7DC",
        textMuted: "#C7C7BD",
        iconPrimary: "#F5F7F4",
        iconSecondary: "#C7C7BD",
        inputBackground: "#3B433C",
        inputBorder: "#606A63",
        inputPlaceholder: "#A7B3A2",
        buttonPrimaryBackground: "#F5F5F5",
        buttonPrimaryForeground: "#2F352F",
        buttonSecondaryBackground: "#4C584F",
        buttonSecondaryForeground: "#F5F7F4",
        interactivePressed: "#DCD8CF",
        interactiveDisabledBackground: "#4D5A4F",
        interactiveDisabledForeground: "#A0A69B",
        success: "#C8F365",
        warning: "#FFB74D",
        error: "#F87171",
        link: "#C8F365",
        navigationBackground: "#404C42",
        navigationTitle: "#C7C7BD",
        tabBarBackground: "#404C42"
    )

    static let dark = AppThemePalette(
        backgroundPrimary: "#0F1113",
        backgroundSecondary: "#121519",
        surfacePrimary: "#1C1F23",
        surfaceSecondary: "#24282D",
        border: "#343A42",
        divider: "#3D444D",
        textPrimary: "#F1F3F5",
        textSecondary: "#D6DBE1",
        textMuted: "#AFB6BF",
        iconPrimary: "#ECEFF3",
        iconSecondary: "#BDC4CD",
        inputBackground: "#24282D",
        inputBorder: "#3D444D",
        inputPlaceholder: "#8E97A2",
        buttonPrimaryBackground: "#E1E6EB",
        buttonPrimaryForeground: "#252A2F",
        buttonSecondaryBackground: "#24282D",
        buttonSecondaryForeground: "#EFF2F5",
        interactivePressed: "#C5CCD3",
        interactiveDisabledBackground: "#2C3138",
        interactiveDisabledForeground: "#929AA5",
        success: "#9FBF9F",
        warning: "#D0A672",
        error: "#E09A9A",
        link: "#C9D0D8",
        navigationBackground: "#0F1113",
        navigationTitle: "#D6DBE1",
        tabBarBackground: "#0F1113"
    )
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

final class AppTheme: ObservableObject {
    static let shared = AppTheme()
    static let modeStorageKey = "pillr.appThemeMode"

    @Published var mode: AppThemeMode {
        didSet {
            guard oldValue != mode else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeStorageKey)
        }
    }
    @Published private(set) var systemColorScheme: ColorScheme

    var preferredColorScheme: ColorScheme? {
        mode.preferredColorScheme
    }

    var resolvedColorScheme: ColorScheme {
        switch mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemColorScheme
        }
    }

    var isUsingDarkPalette: Bool {
        resolvedColorScheme == .dark
    }

    var palette: AppThemePalette {
        isUsingDarkPalette ? .dark : .light
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.modeStorageKey)
        mode = AppThemeMode(rawValue: raw ?? "") ?? .system
        systemColorScheme = Self.detectCurrentSystemColorScheme()
    }

    func setMode(_ mode: AppThemeMode) {
        self.mode = mode
    }

    func updateSystemColorScheme(_ colorScheme: ColorScheme) {
        guard systemColorScheme != colorScheme else { return }
        systemColorScheme = colorScheme
    }

    static var currentMode: AppThemeMode {
        shared.mode
    }

    static var currentPalette: AppThemePalette {
        shared.palette
    }

    struct RGBAComponents {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    static func literalComponents(for hex: String) -> RGBAComponents {
        parseHexToRGBA(normalizeHex(hex))
    }

    static func themedComponents(for hex: String) -> RGBAComponents {
        let normalized = normalizeHex(hex)
        var parsed = parseHexToRGBA(normalized)

        guard shared.isUsingDarkPalette else {
            return parsed
        }

        let baseHex = rgbHex(from: normalized)

        if let overrideHex = darkHexOverrides[baseHex] ?? darkStatusOverrides[baseHex] {
            let overrideColor = parseHexToRGBA(normalizeHex(overrideHex))
            return RGBAComponents(
                red: overrideColor.red,
                green: overrideColor.green,
                blue: overrideColor.blue,
                alpha: parsed.alpha
            )
        }

        parsed = neutralizeForDarkMode(parsed)
        return parsed
    }

    private static let darkHexOverrides: [String: String] = [
        "0A0F0C": "#0F1113",
        "1B1D19": "#1C1F23",
        "1E201A": "#1C1F23",
        "1E2620": "#24282D",
        "2A2D28": "#1C1F23",
        "2C332D": "#24282D",
        "2E352F": "#24282D",
        "2F352F": "#24282D",
        "303830": "#24282D",
        "343D36": "#24282D",
        "3A443D": "#121519",
        "3B433C": "#24282D",
        "3C463E": "#24282D",
        "3D463F": "#24282D",
        "3E483F": "#24282D",
        "404C42": "#0F1113",
        "424C43": "#1C1F23",
        "4A5A4A": "#1C1F23",
        "4C584F": "#1C1F23",
        "4D5A4F": "#1C1F23",
        "525E55": "#1C1F23",
        "5B695D": "#1C1F23",
        "606A63": "#343A42",
        "616D5F": "#343A42",
        "A0A69B": "#8E97A1",
        "A7B3A2": "#99A2AB",
        "B8B8AE": "#A9B1BB",
        "C7C7BD": "#AFB6BF",
        "C8CCBE": "#B5BCC5",
        "D0D0C8": "#BEC4CD",
        "D0D5D8": "#C4CBD3",
        "D7CCC8": "#C2C9D1",
        "DCD8CF": "#C8CED6",
        "DFDFD9": "#CFD4DB",
        "E0E0E0": "#D1D6DC",
        "E0E7DC": "#D6DBE1",
        "E1D6C5": "#C6CDD4",
        "E8E8E0": "#DEE3E9",
        "F0F0E8": "#E5E8EC",
        "F5F1E8": "#E5E8EC",
        "F5F5F5": "#ECEFF3",
        "F5F7F4": "#F1F3F5",
        "F8F8F1": "#F2F4F6"
    ]

    private static let darkStatusOverrides: [String: String] = [
        "64B5F6": "#AFBED0",
        "7FE3FF": "#B9CEDA",
        "81C784": "#8FAF95",
        "8BC34A": "#94AD7B",
        "9FD7C1": "#B7C7C2",
        "B6C7E6": "#C5CEDA",
        "C7A76B": "#B29874",
        "C8F365": "#9FBF9F",
        "D4A017": "#B38C58",
        "D78B7E": "#B98E88",
        "D8B4F8": "#C3C8D0",
        "DFFFC0": "#CED5C8",
        "F2B8A0": "#D2ADA0",
        "F3D6D6": "#DDBEC2",
        "F44336": "#C97B76",
        "F6FFE0": "#D6DBD0",
        "F87171": "#E09A9A",
        "FF5A5A": "#D68A8A",
        "FF6B6B": "#DC9393",
        "FF8A65": "#C99983",
        "FF9800": "#C08355",
        "FFA726": "#C99562",
        "FFB74D": "#D0A672",
        "FFC107": "#D4B06E",
        "FFC857": "#CBA56F",
        "FFE4E6": "#E6C9CC",
        "7A3330": "#93615E",
        "8C3A37": "#A66F6B"
    ]

    private static func neutralizeForDarkMode(_ color: RGBAComponents) -> RGBAComponents {
        let luminance = (0.2126 * color.red) + (0.7152 * color.green) + (0.0722 * color.blue)
        let clampedGray = min(max(0.14 + (luminance * 0.72), 0.14), 0.93)
        return RGBAComponents(
            red: clampedGray,
            green: clampedGray,
            blue: clampedGray,
            alpha: color.alpha
        )
    }

    private static func normalizeHex(_ hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        switch cleaned.count {
        case 3:
            return cleaned.map { "\($0)\($0)" }.joined()
        case 6, 8:
            return cleaned
        default:
            return "FFFFFFFF"
        }
    }

    private static func parseHexToRGBA(_ normalizedHex: String) -> RGBAComponents {
        var int: UInt64 = 0
        Scanner(string: normalizedHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch normalizedHex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            // ARGB format.
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        return RGBAComponents(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            alpha: Double(a) / 255.0
        )
    }

    private static func rgbHex(from normalizedHex: String) -> String {
        if normalizedHex.count == 8 {
            return String(normalizedHex.suffix(6))
        }
        return normalizedHex
    }

    private static func detectCurrentSystemColorScheme() -> ColorScheme {
        let style: UIUserInterfaceStyle
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = scene.windows.first {
            style = window.traitCollection.userInterfaceStyle
        } else {
            style = UITraitCollection.current.userInterfaceStyle
        }
        return style == .light ? .light : .dark
    }
}

private struct PillrThemeModeKey: EnvironmentKey {
    static let defaultValue: AppThemeMode = .system
}

extension EnvironmentValues {
    var pillrThemeMode: AppThemeMode {
        get { self[PillrThemeModeKey.self] }
        set { self[PillrThemeModeKey.self] = newValue }
    }
}

// MARK: - Global Background Definition
extension Color {
    static var pillrNavy: Color { AppTheme.shared.palette.backgroundPrimaryColor }
    static var pillrSoftBlue: Color { AppTheme.shared.palette.backgroundSecondaryColor }
    static var pillrDeepBlue: Color { AppTheme.shared.palette.surfacePrimaryColor }
}

extension LinearGradient {
    static var pillrBackground: LinearGradient {
        let palette = AppTheme.shared.palette
        return LinearGradient(
            gradient: Gradient(colors: [palette.backgroundPrimaryColor, palette.backgroundSecondaryColor]),
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
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
        AppTheme.shared.palette.buttonPrimaryBackgroundColor
    }

    static var pillrSecondary: Color {
        AppTheme.shared.palette.textSecondaryColor
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hexLiteral: String) {
        let components = AppTheme.literalComponents(for: hexLiteral)
        self.init(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }

    init(hex: String) {
        let components = AppTheme.themedComponents(for: hex)
        self.init(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
}

extension UIColor {
    convenience init(hexLiteral: String) {
        let components = AppTheme.literalComponents(for: hexLiteral)
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
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
        .onChange(of: showingPopoutMenu) { _, newValue in
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
        .onChange(of: animateItems) { _, newValue in
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
            return !log.skipped && log.isDoseLog && medicationMatch
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
        let names = Set(store.logs.filter { !$0.skipped && $0.isDoseLog }.map { $0.medicationName })
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
                            StatCard(title: "Total Doses", value: "\(store.logs.filter { !$0.skipped && $0.isDoseLog }.count)", icon: "pills.fill")
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
                        if store.logs.filter({ !$0.skipped && $0.isDoseLog }).isEmpty {
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
            !log.skipped && log.isDoseLog && log.takenAt >= weekAgo && log.takenAt <= now
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
                !log.skipped && log.isDoseLog && calendar.isDate(log.takenAt, inSameDayAs: currentDate)
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
            (selectedMedicationFilter == "All" || log.medicationName == selectedMedicationFilter) &&
            log.isDoseLog
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
                let dosage = log.recordedDosageWithUnit
                
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
                
                // Present the share sheet
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    // Ensure iPad gets a popover
                    if let popoverController = activityVC.popoverPresentationController {
                        popoverController.sourceView = rootViewController.view
                        popoverController.sourceRect = CGRect(
                            x: UIScreen.main.bounds.width / 2,
                            y: UIScreen.main.bounds.height / 2,
                            width: 0,
                            height: 0
                        )
                        popoverController.permittedArrowDirections = []
                    }
                    
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
                    Image(systemName: "lock")
                        .foregroundColor(Color(hex: "#C7C7BD"))
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
