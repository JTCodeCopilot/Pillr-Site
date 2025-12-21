import SwiftUI

enum CloudSyncChoice {
    case onDeviceOnly
    case connect
}

struct CloudSyncChoiceOverlay: View {
    let onChoice: (CloudSyncChoice) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.74)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            VStack(spacing: 10) {
                                VStack(spacing: 6) {
                                    Text("Welcome to Pillr!")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("First, choose how your medications are stored.")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Rectangle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 10)

                                Text("Pick what works for you.\nYou can change this later in Settings.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.65))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(spacing: 16) {
                                CloudSyncChoiceCard(
                                    iconName: "internaldrive",
                                    title: "On device only",
                                    description: "Your medication data stays only on this phone. It is not shared with iCloud unless you turn it on later.",
                                    highlights: [
                                        "Stored only on this device",
                                        "No backup or syncing",
                                        "Data is lost if you delete Pillr or reset this phone"
                                    ],
                                    accentColor: Color.white.opacity(0.9),
                                    filled: false,
                                    action: {
                                        onChoice(.onDeviceOnly)
                                    }
                                )

                                CloudSyncChoiceCard(
                                    iconName: "icloud.and.arrow.up",
                                    title: "Connect iCloud Sync (recommended)",
                                    description: "Your medication history is encrypted and safely synced across all your Apple devices using your Apple ID.",
                                    highlights: [
                                        "Automatic backup and sync",
                                        "Access your logs on all devices",
                                        "History is restored if you change or reset devices"
                                    ],
                                    accentColor: Color(hex: "#2A2C27"),
                                    filled: true,
                                    iconColor: Color(hex: "#2A2C27"),
                                    tapBackgroundColor: Color(hex: "#2A2C27"),
                                    tapTextColor: Color.white,
                                    action: {
                                        onChoice(.connect)
                                    }
                                )
                            }

                            Text("You must choose one option to keep going.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .padding(.top, 6)
                        }
                        .padding(28)
                        .frame(maxWidth: 460)
                    }
                    .frame(maxWidth: 460, maxHeight: geometry.size.height * 0.78)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(hex: "#2A2D28").opacity(0.98))
                            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                }
            }
        }
        .transition(.opacity)
        .zIndex(2)
    }
}

private struct CloudSyncChoiceCard: View {
    let iconName: String
    let title: String
    let description: String
    let highlights: [String]
    let accentColor: Color
    var filled: Bool = false
    var iconColor: Color? = nil
    var tapBackgroundColor: Color? = nil
    var tapTextColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor ?? (filled ? Color.white : accentColor))

                    Text(title)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(filled ? Color(hex: "#404C42") : Color.white)
                }

                Text(description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(filled ? Color(hex: "#404C42").opacity(0.9) : Color.white.opacity(0.9))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(highlights, id: \.self) { highlight in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(filled ? Color(hex: "#404C42") : accentColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            Text(highlight)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(filled ? Color(hex: "#404C42").opacity(0.9) : Color.white.opacity(0.8))
                        }
                    }
                }

                HStack {
                    Spacer(minLength: 0)
                    Text("Tap to select")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(tapTextColor ?? (filled ? Color(hex: "#404C42") : accentColor))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    tapBackgroundColor
                                    ?? (filled ? Color.white.opacity(0.8) : Color.white.opacity(0.08))
                                )
                        )
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(filled ? Color.white : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(filled ? Color.clear : accentColor.opacity(0.5), lineWidth: filled ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CloudSyncChoiceConfirmationOverlay: View {
    let choice: CloudSyncChoice
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var title: String {
        switch choice {
        case .onDeviceOnly:
            return "Keep data on this device?"
        case .connect:
            return "Enable iCloud Sync?"
        }
    }

    private var description: String {
        switch choice {
        case .onDeviceOnly:
            return "Everything stays local. If you delete Pillr or reset this device, your medication data is gone forever unless you enable iCloud Sync later."
        case .connect:
            return "Medication data and history are backed up and mirrored across every Apple device signed in with your Apple ID, helping you recover or continue on new devices."
        }
    }

    private var confirmTitle: String {
        switch choice {
        case .onDeviceOnly:
            return "Confirm On-device only"
        case .connect:
            return "Confirm Connect iCloud Sync"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Text(title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(description)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Button(action: onConfirm) {
                            Text(confirmTitle)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#404C42"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: onCancel) {
                            Text("Go back")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(28)
                    .frame(maxWidth: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color(hex: "#2A2D28").opacity(0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                }
            }
        }
        .transition(.opacity)
        .zIndex(3)
    }
}
