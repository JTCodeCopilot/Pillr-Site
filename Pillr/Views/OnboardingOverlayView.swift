//
//  OnboardingOverlayView.swift
//  Pillr
//
//  Created by Codex on 2025-XX-XX.
//

import SwiftUI

enum OnboardingIcon {
    case system(name: String)
    case asset(name: String)
}

struct OnboardingStageInfo {
    let title: String
    let description: AnyView
    let benefits: [String]
    let icon: OnboardingIcon
    let accentColor: Color
    let buttonAccessibilityLabel: String
    let subtitle: String?
    let buttonTitle: String
    let verticalOffset: CGFloat

    init(
        title: String,
        description: AnyView,
        benefits: [String],
        icon: OnboardingIcon,
        accentColor: Color,
        buttonAccessibilityLabel: String,
        subtitle: String? = nil,
        buttonTitle: String = "Done",
        verticalOffset: CGFloat = 0
    ) {
        self.title = title
        self.description = description
        self.benefits = benefits
        self.icon = icon
        self.accentColor = accentColor
        self.buttonAccessibilityLabel = buttonAccessibilityLabel
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.verticalOffset = verticalOffset
    }
}

struct OnboardingOverlayView: View {
    let info: OnboardingStageInfo
    let onDismiss: () -> Void
    @State private var isPresented = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(isPresented ? 0.72 : 0)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.2), value: isPresented)

                VStack {
                    Spacer()

                    OnboardingCardView(info: info, onDismiss: onDismiss, animateContent: isPresented)
                        .opacity(isPresented ? 1 : 0)
                        .scaleEffect(isPresented ? 1 : 0.97)
                        .offset(y: info.verticalOffset + (isPresented ? 0 : 22))
                        .padding(.horizontal, 16)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isPresented)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            }
            .onAppear {
                isPresented = true
            }
            .onDisappear {
                isPresented = false
            }
        }
    }
}

struct OnboardingCardView: View {
    let info: OnboardingStageInfo
    let onDismiss: () -> Void
    let animateContent: Bool

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                iconContent

                Text(info.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let subtitle = info.subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 10)
            .animation(.easeOut(duration: 0.26).delay(0.04), value: animateContent)

            VStack(alignment: .leading, spacing: 16) {
                info.description
                    .foregroundColor(Color.white.opacity(0.85))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .environment(\.multilineTextAlignment, .leading)
                    .frame(maxWidth: 420, alignment: .leading)

                if !info.benefits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(info.benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(info.accentColor)
                                    .frame(width: 9, height: 9)
                                    .padding(.top, 5)

                                Text(benefit)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                }
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 14)
            .animation(.easeOut(duration: 0.28).delay(0.1), value: animateContent)

            Button(action: onDismiss) {
                Text(info.buttonTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.pillrPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(info.buttonAccessibilityLabel)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 12)
            .animation(.easeOut(duration: 0.24).delay(0.14), value: animateContent)
        }
        .padding(.all, 28)
        .frame(maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.pillrPrimary.opacity(0.98))
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var iconContent: some View {
        switch info.icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.white)
        case .asset(let name):
            Image(name)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
        }
    }
}
